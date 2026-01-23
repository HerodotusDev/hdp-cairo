pub mod header;
pub mod storage;

use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager, types::relocatable::Relocatable, vm::vm_core::VirtualMachine,
};
use serde::{Deserialize, Serialize};
use syscall_handler::{
    call_contract::StarknetCallHandlerId, memorizer::Memorizer, traits, traits::CallHandler, SyscallExecutionError, SyscallResult,
    WriteResponseResult,
};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
    },
    keys::starknet,
};

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

impl traits::SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        Err(SyscallExecutionError::InternalError(
            "sound starknet::CallContractHandler::read_request should not be called (request is parsed by relay)".into(),
        ))
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = StarknetCallHandlerId::try_from(request.contract_address)?;

        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            StarknetCallHandlerId::Header => {
                let key = header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = header::HeaderCallHandler::derive_id(request.selector)?;
                let result = header::HeaderCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <header::HeaderCallHandler as CallHandler>::CallHandlerResult::n_fields(vm, retdata_end)?;
            }
            StarknetCallHandlerId::Storage => {
                let key = storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = storage::StorageCallHandler::derive_id(request.selector)?;
                let result = storage::StorageCallHandler::new(memorizer, self.dict_manager.clone())
                    .handle(key.clone(), function_id, vm)
                    .await?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <storage::StorageCallHandler as CallHandler>::CallHandlerResult::n_fields(vm, retdata_end)?;
            }
        }

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        Err(SyscallExecutionError::InternalError(
            "sound starknet::CallContractHandler::write_response should not be called (response is written by relay)".into(),
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
    pub fn is_header(&self) -> bool {
        matches!(self, Self::Header(_))
    }

    pub fn is_storage(&self) -> bool {
        matches!(self, Self::Storage(_))
    }
}
