use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
};
use serde::{Deserialize, Serialize};
use syscall_handler::{
    call_contract::UnconstrainedCallHandlerId, memorizer::Memorizer, traits, SyscallExecutionError, SyscallResult, WriteResponseResult,
};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
        unconstrained::bytecode::BytecodeLeWords,
    },
    keys,
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
            "sound unconstrained::CallContractHandler::read_request should not be called (request is parsed by relay)".into(),
        ))
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = UnconstrainedCallHandlerId::try_from(request.selector)?;

        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            UnconstrainedCallHandlerId::Bytecode => {
                let key = keys::evm::account::CairoKey::from_memory(vm, calldata)?;
                let ptr = vm
                    .get_maybe(&memorizer.read_key_ptr(&MaybeRelocatable::Int(key.hash()), self.dict_manager.clone())?)
                    .ok_or(SyscallExecutionError::InternalError("No key for pointer".into()))?;

                let reloc = ptr
                    .get_relocatable()
                    .ok_or_else(|| SyscallExecutionError::InternalError("Expected relocatable pointer in memorizer dict".into()))?;
                retdata_end = BytecodeLeWords::from_memory(vm, reloc)?.to_memory(vm, retdata_end)?;
            }
        }

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        Err(SyscallExecutionError::InternalError(
            "sound unconstrained::CallContractHandler::write_response should not be called (response is written by relay)".into(),
        ))
    }
}
