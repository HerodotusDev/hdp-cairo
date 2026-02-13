use std::collections::HashSet;

use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};
use header::HeaderCallHandler;
use serde::{Deserialize, Serialize};
use storage::StorageCallHandler;
use syscall_handler::{
    call_contract::StarknetCallHandlerId,
    felt_from_ptr,
    traits::{CallHandler, SyscallHandler},
    SyscallExecutionError, SyscallResult, WriteResponseResult,
};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
    },
    keys::starknet,
};
pub mod header;
pub mod storage;

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandler {
    pub key_set: HashSet<DryRunKey>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        Err(SyscallExecutionError::InternalError(
            "dry starknet::CallContractHandler::read_request should not be called (request is parsed by relay)".into(),
        ))
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = StarknetCallHandlerId::try_from(request.contract_address)?;
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
            StarknetCallHandlerId::Header => {
                let key = HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = HeaderCallHandler::derive_id(request.selector)?;
                let result = HeaderCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Header(key));
                result.to_memory(vm, retdata_end)?;
                retdata_end += <HeaderCallHandler as CallHandler>::CallHandlerResult::n_fields(vm, retdata_end)?;
            }
            StarknetCallHandlerId::Storage => {
                let key = StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = StorageCallHandler::derive_id(request.selector)?;
                let result = StorageCallHandler.handle(key.clone(), function_id, vm).await?;
                self.key_set.insert(DryRunKey::Storage(key));
                result.to_memory(vm, retdata_end)?;
                retdata_end += <StorageCallHandler as CallHandler>::CallHandlerResult::n_fields(vm, retdata_end)?;
            }
        }

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        Err(SyscallExecutionError::InternalError(
            "dry starknet::CallContractHandler::write_response should not be called (response is written by relay)".into(),
        ))
    }
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Clone)]
#[serde(rename_all = "lowercase")]
pub enum DryRunKey {
    Header(starknet::header::Key),
    Storage(starknet::storage::Key),
}

impl DryRunKey {
    pub fn is_storage(&self) -> bool {
        matches!(self, Self::Storage(_))
    }
}
