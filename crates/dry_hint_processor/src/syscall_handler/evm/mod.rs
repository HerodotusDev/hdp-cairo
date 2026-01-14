pub mod account;
pub mod header;
pub mod log;
pub mod receipt;
pub mod storage;
pub mod transaction;

use std::{collections::HashSet, hash::Hash};

use alloy::primitives::Address;
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

// 'evm_executor' as felt252 = 0x65766d5f6578656375746f72
const EVM_EXECUTOR_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x65766d5f6578656375746f72");

#[derive(FromRepr)]
pub enum CallHandlerId {
    Header = 0,
    Account = 1,
    Storage = 2,
    Transaction = 3,
    Receipt = 4,
    Log = 5,
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

        // Handle evm_executor syscall specially during dry-run
        // This records the target contract's account key for bytecode fetching
        // and returns a mock success response (actual EVM execution happens in sound-run)
        if request.contract_address == EVM_EXECUTOR_ADDRESS {
            return self.handle_evm_executor_dry_run(vm, &mut calldata).await;
        }

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

impl CallContractHandler {
    /// Handle evm_executor syscall during dry-run
    /// 
    /// Syscall calldata format:
    /// [0]: chain_id
    /// [1]: block_number
    /// [2]: timestamp
    /// [3]: address (target contract)
    /// [4]: caller
    /// [5]: origin
    /// [6]: value_low
    /// [7]: value_high
    /// [8]: gas_limit
    /// [9]: read_only
    /// [10]: depth
    /// [11]: calldata_len
    /// [12...]: calldata bytes
    async fn handle_evm_executor_dry_run(
        &mut self,
        vm: &mut VirtualMachine,
        calldata: &mut Relocatable,
    ) -> SyscallResult<CallContractResponse> {
        // Parse calldata to extract target contract info
        let chain_id = felt_from_ptr(vm, calldata)?;
        let block_number = felt_from_ptr(vm, calldata)?;
        let _timestamp = felt_from_ptr(vm, calldata)?;
        let address = felt_from_ptr(vm, calldata)?;
        // Skip remaining fields (caller, origin, value, gas_limit, read_only, depth, calldata)

        // Record the target contract's account key for bytecode fetching
        let account_key = evm::account::Key {
            chain_id: chain_id.try_into().map_err(|e| {
                SyscallExecutionError::InternalError(format!("Invalid chain_id: {}", e).into())
            })?,
            block_number: block_number.try_into().map_err(|e| {
                SyscallExecutionError::InternalError(format!("Invalid block_number: {}", e).into())
            })?,
            address: Address::try_from(address.to_biguint().to_bytes_be().as_slice()).map_err(|e| {
                SyscallExecutionError::InternalError(format!("Invalid address: {}", e).into())
            })?,
        };

        // Record the account key for dependency tracking
        // Note: The bytecode key is recorded separately by the unconstrained handler
        // when the bytecode syscall is made. The account key here ensures the account
        // state is fetched, which may be needed for other operations.
        self.key_set.insert(DryRunKey::Account(account_key));

        // Return mock success response
        // During dry-run, we don't actually execute the EVM - just record dependencies
        // The actual execution happens during sound-run
        // Response format must match sound-run: [success, gas_used, return_data_len, ...return_data]
        let retdata_start = vm.add_memory_segment();
        
        // Write mock return data: [success=1, gas_used=0, return_data_len=0]
        // This matches the format expected by execute_eth_call_zero
        vm.insert_value(retdata_start, Felt252::ONE)?; // success
        vm.insert_value((retdata_start + 1)?, Felt252::ZERO)?; // gas_used (0 in dry-run)
        vm.insert_value((retdata_start + 2)?, Felt252::ZERO)?; // return_data_len (0 in dry-run)
        let retdata_end = (retdata_start + 3)?;

        Ok(CallContractResponse {
            retdata_start,
            retdata_end,
        })
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
