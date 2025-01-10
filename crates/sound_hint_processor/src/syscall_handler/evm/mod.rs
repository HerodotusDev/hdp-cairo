pub mod account;
pub mod header;
pub mod receipt;
pub mod storage;
pub mod transaction;

use cairo_vm::hint_processor::builtin_hint_processor::dict_manager::DictManager;
use cairo_vm::vm::errors::hint_errors::HintError;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::rc::Rc;
use std::{collections::HashSet, hash::Hash};
use strum_macros::FromRepr;
use syscall_handler::traits::CallHandler;
use syscall_handler::{felt_from_ptr, run_handler, traits, SyscallExecutionError, SyscallResult, SyscallSelector, WriteResponseResult};
use tokio::sync::RwLock;
use tokio::task;
use types::cairo::new_syscalls::{CallContractRequest, CallContractResponse};
use types::cairo::traits::CairoType;
use types::keys;

use super::Memorizer;

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct SyscallHandler {
    #[serde(skip)]
    pub syscall_ptr: Option<Relocatable>,
    pub call_contract_handler: CallContractHandler,
}

impl SyscallHandler {
    pub fn new(dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self {
            call_contract_handler: CallContractHandler::new(dict_manager),
            ..Default::default()
        }
    }
}

/// SyscallHandler is wrapped in Rc<RefCell<_>> in order
/// to clone the reference when entering and exiting vm scopes
#[derive(Debug, Clone, Default)]
pub struct SyscallHandlerWrapper {
    pub syscall_handler: Rc<RwLock<SyscallHandler>>,
}

#[derive(FromRepr)]
pub enum CallHandlerId {
    Header = 0,
    Account = 1,
    Storage = 2,
    Transaction = 3,
    Receipt = 4,
}

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct CallContractHandler {
    #[serde(skip)]
    pub dict_manager: Rc<RefCell<DictManager>>,
    pub key_set: HashSet<DryRunKey>,
}

impl CallContractHandler {
    pub fn new(dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self {
            dict_manager,
            ..Default::default()
        }
    }
}

impl SyscallHandlerWrapper {
    pub fn new(dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self {
            syscall_handler: Rc::new(RwLock::new(SyscallHandler::new(dict_manager))),
        }
    }
    pub fn set_syscall_ptr(&self, syscall_ptr: Relocatable) {
        let mut syscall_handler = task::block_in_place(|| self.syscall_handler.blocking_write());
        syscall_handler.syscall_ptr = Some(syscall_ptr);
    }

    pub fn syscall_ptr(&self) -> Option<Relocatable> {
        let syscall_handler = task::block_in_place(|| self.syscall_handler.blocking_read());
        syscall_handler.syscall_ptr
    }

    pub async fn execute_syscall(&mut self, vm: &mut VirtualMachine, syscall_ptr: Relocatable) -> Result<(), HintError> {
        let mut syscall_handler = self.syscall_handler.write().await;
        let ptr = &mut syscall_handler
            .syscall_ptr
            .ok_or(HintError::CustomHint(Box::from("syscall_ptr is None")))?;

        assert_eq!(*ptr, syscall_ptr);

        match SyscallSelector::try_from(felt_from_ptr(vm, ptr)?)? {
            SyscallSelector::CallContract => run_handler(&mut syscall_handler.call_contract_handler, ptr, vm).await,
        }?;

        syscall_handler.syscall_ptr = Some(*ptr);

        Ok(())
    }
}

impl traits::SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.contract_address)?;

        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_temporary_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Header => {
                let key = header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = header::HeaderCallHandler::derive_id(request.selector)?;
                let result = header::HeaderCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                self.key_set.insert(DryRunKey::Header(
                    key.try_into()
                        .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
                ));
                result.to_memory(vm, retdata_end)?;
                retdata_end += <header::HeaderCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            CallHandlerId::Account => {
                let key = account::AccountCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = account::AccountCallHandler::derive_id(request.selector)?;
                let result = account::AccountCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                self.key_set.insert(DryRunKey::Account(
                    key.try_into()
                        .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
                ));
                result.to_memory(vm, retdata_end)?;
                retdata_end += <account::AccountCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            CallHandlerId::Storage => {
                let key = storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = storage::StorageCallHandler::derive_id(request.selector)?;
                let result = storage::StorageCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                self.key_set.insert(DryRunKey::Storage(
                    key.try_into()
                        .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
                ));
                result.to_memory(vm, retdata_end)?;
                retdata_end += <storage::StorageCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            _ => {}
        }

        Ok(Self::Response { retdata_start, retdata_end })
    }

    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}

impl TryFrom<Felt252> for CallHandlerId {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        Self::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })
    }
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum DryRunKey {
    Account(keys::evm::account::Key),
    Header(keys::evm::header::Key),
    Storage(keys::evm::storage::Key),
}

impl DryRunKey {
    pub fn is_account(&self) -> bool {
        matches!(self, Self::Account(_))
    }

    pub fn is_header(&self) -> bool {
        matches!(self, Self::Header(_))
    }

    pub fn is_storage(&self) -> bool {
        matches!(self, Self::Storage(_))
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DryRunKeySet(HashSet<DryRunKey>);
