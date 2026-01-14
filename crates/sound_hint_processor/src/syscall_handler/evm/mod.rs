pub mod account;
pub mod header;
pub mod log;
pub mod receipt;
pub mod storage;
pub mod transaction;

use std::{cell::RefCell, hash::Hash, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager, types::relocatable::Relocatable, vm::vm_core::VirtualMachine,
    Felt252,
};
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{memorizer::Memorizer, traits, traits::CallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
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
    Logs = 5,
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandler {
    #[serde(skip)]
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl CallContractHandler {
    pub fn new(dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { dict_manager }
    }
}

// 'evm_executor' as felt252 = 0x65766d5f6578656375746f72
const EVM_EXECUTOR_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x65766d5f6578656375746f72");

impl traits::SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        // Handle evm_executor specially - allocate segment for Cairo Zero to use
        // The actual EVM execution happens in Cairo Zero's execute_evm_call_from_syscall
        // which will populate the response based on EVM execution results
        // Format: [success, gas_used, retdata_len, ...retdata]
        // Note: We don't write placeholders here - Cairo Zero will write the actual values via memcpy
        // Writing placeholders causes DiffAssertValues errors when Cairo Zero tries to overwrite them
        if request.contract_address == EVM_EXECUTOR_ADDRESS {
            let retdata_start = vm.add_memory_segment();
            // Allocate space but don't write placeholders - Cairo Zero will write via memcpy
            // Set retdata_end = retdata_start + 3 (minimum for [success, gas_used, retdata_len])
            // Cairo Zero will update this to the actual size after writing
            let retdata_end = (retdata_start + 3)?;
            return Ok(Self::Response {
                retdata_start,
                retdata_end,
            });
        }

        let mut calldata = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.contract_address)?;

        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Header => {
                let key = header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = header::HeaderCallHandler::derive_id(request.selector)?;
                let result = header::HeaderCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Account => {
                let key = account::AccountCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = account::AccountCallHandler::derive_id(request.selector)?;
                let result = account::AccountCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Storage => {
                let key = storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = storage::StorageCallHandler::derive_id(request.selector)?;
                let result = storage::StorageCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Transaction => {
                let key = transaction::TransactionCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = transaction::TransactionCallHandler::derive_id(request.selector)?;
                let result = transaction::TransactionCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Receipt => {
                let key = receipt::ReceiptCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = receipt::ReceiptCallHandler::derive_id(request.selector)?;
                let result = receipt::ReceiptCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Logs => {
                let key = log::LogsCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = log::LogsCallHandler::derive_id(request.selector)?;
                let result = log::LogsCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
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
