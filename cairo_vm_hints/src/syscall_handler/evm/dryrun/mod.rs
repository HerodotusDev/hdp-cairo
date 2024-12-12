#![allow(unused)]
pub mod account;
pub mod header;
pub mod receipt;
pub mod storage;
pub mod transaction;

use crate::cairo_types::traits::CairoType;
use crate::syscall_handler::traits::{self, CallHandler};
use crate::syscall_handler::utils::{run_handler, SyscallSelector};
use crate::{
    cairo_types::new_syscalls::{CallContractRequest, CallContractResponse},
    syscall_handler::utils::{felt_from_ptr, SyscallExecutionError, SyscallResult, WriteResponseResult},
};
use cairo_vm::vm::errors::hint_errors::HintError;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::rc::Rc;
use std::sync::RwLock;
use std::{collections::HashSet, hash::Hash, marker::PhantomData};
use strum_macros::FromRepr;

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct SyscallHandler {
    #[serde(skip)]
    syscall_ptr: Option<Relocatable>,
    call_contract_handler: CallContractHandler,
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
    key_set: HashSet<DryRunKey>,
}

impl SyscallHandlerWrapper {
    pub fn new() -> Self {
        Self {
            syscall_handler: Rc::new(RwLock::new(SyscallHandler::default())),
        }
    }
    pub fn set_syscall_ptr(&self, syscall_ptr: Relocatable) {
        let mut syscall_handler = self.syscall_handler.write().unwrap();
        syscall_handler.syscall_ptr = Some(syscall_ptr);
    }

    pub fn syscall_ptr(&self) -> Option<Relocatable> {
        let syscall_handler = self.syscall_handler.read().unwrap();
        syscall_handler.syscall_ptr
    }

    pub fn execute_syscall(&mut self, vm: &mut VirtualMachine, syscall_ptr: Relocatable) -> Result<(), HintError> {
        let mut syscall_handler = self.syscall_handler.write().unwrap();
        let ptr = &mut syscall_handler
            .syscall_ptr
            .ok_or(HintError::CustomHint(Box::from("syscall_ptr is None")))?;

        assert_eq!(*ptr, syscall_ptr);

        match SyscallSelector::try_from(felt_from_ptr(vm, ptr)?)? {
            SyscallSelector::CallContract => run_handler(&mut syscall_handler.call_contract_handler, ptr, vm),
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

    fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.contract_address)?;

        let segment_index = felt_from_ptr(vm, &mut calldata)?;
        let offset = felt_from_ptr(vm, &mut calldata)?;

        let _memorizer = Relocatable::from((
            segment_index
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            offset
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
        ));

        let retdata_start = vm.add_temporary_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Header => {
                let key = header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = header::HeaderCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = header::HeaderCallHandler::handle(key.clone(), function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <header::HeaderCallHandler as CallHandler>::CallHandlerResult::n_fields();
                self.key_set.insert(DryRunKey::Header(key));
            }
            CallHandlerId::Account => {
                let key = account::AccountCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = account::AccountCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = account::AccountCallHandler::handle(key.clone(), function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <account::AccountCallHandler as CallHandler>::CallHandlerResult::n_fields();
                self.key_set.insert(DryRunKey::Account(key));
            }
            CallHandlerId::Storage => {
                let key = storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = storage::StorageCallHandler::derive_id(request.selector)?;
                let result = storage::StorageCallHandler::handle(key.clone(), function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <storage::StorageCallHandler as CallHandler>::CallHandlerResult::n_fields();
                self.key_set.insert(DryRunKey::Storage(key));
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
enum DryRunKey {
    Account(account::Key),
    Header(header::Key),
    Storage(storage::Key),
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DryRunKeySet(HashSet<DryRunKey>);
