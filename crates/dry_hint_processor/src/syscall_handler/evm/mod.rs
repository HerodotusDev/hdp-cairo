pub mod account;
pub mod header;
pub mod log;
pub mod receipt;
pub mod storage;
pub mod transaction;

use std::{collections::HashSet, hash::Hash};

use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{
    felt_from_ptr,
    traits::{CallHandler, SyscallHandler},
    SyscallExecutionError, SyscallResult, WriteResponseResult,
};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
    },
    keys::evm,
};

#[derive(FromRepr)]
pub enum CallHandlerId {
    Header = 0,
    Account = 1,
    Storage = 2,
    Transaction = 3,
    Receipt = 4,
    Log = 5,
    UnconstrainedStore = 6,
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandler {
    pub key_set: HashSet<DryRunKey>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
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

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;
        match call_handler_id {
            CallHandlerId::Header => {
                let key = header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = header::HeaderCallHandler::derive_id(request.selector)?;
                let result = header::HeaderCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Header(key));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Account => {
                let key = account::AccountCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = account::AccountCallHandler::derive_id(request.selector)?;
                let result = account::AccountCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Account(key));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            // TODO: @beeinger [wip]
            CallHandlerId::UnconstrainedStore => {
                // let key = account::UnconstrainedStoreCallHandler::derive_key(vm, &mut calldata)?;
                // let function_id = account::UnconstrainedStoreHandler::derive_id(request.selector)?;
                // let result = account::AccountCallHandler.handle(key.clone(), function_id, vm).await?;
                // self.key_set.insert(DryRunKey::UnconstrainedStore(key));
                // retdata_end = result.to_memory(vm, retdata_end)?;
                panic!("Unconstrained storage is not supported yet");
            }
            CallHandlerId::Storage => {
                let key = storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = storage::StorageCallHandler::derive_id(request.selector)?;
                let result = storage::StorageCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Storage(key));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Transaction => {
                let key = transaction::TransactionCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = transaction::TransactionCallHandler::derive_id(request.selector)?;
                let result = transaction::TransactionCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Tx(key));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Receipt => {
                let key = receipt::ReceiptCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = receipt::ReceiptCallHandler::derive_id(request.selector)?;
                let result = receipt::ReceiptCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Receipt(key));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Log => {
                let key = log::LogCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = log::LogCallHandler::derive_id(request.selector)?;
                let result = log::LogCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Receipt(key.into()));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
        }

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        unreachable!()
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

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Clone)]
#[serde(rename_all = "lowercase")]
pub enum DryRunKey {
    Account(evm::account::Key),
    Header(evm::header::Key),
    Storage(evm::storage::Key),
    Receipt(evm::receipt::Key),
    Tx(evm::transaction::Key),
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

    pub fn is_receipt(&self) -> bool {
        matches!(self, Self::Receipt(_))
    }

    pub fn is_tx(&self) -> bool {
        matches!(self, Self::Tx(_))
    }
}
