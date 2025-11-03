use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
    Felt252,
};
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{memorizer::Memorizer, traits, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
        unconstrained::bytecode::BytecodeLeWords,
    },
    keys,
};

#[derive(FromRepr)]
pub enum CallHandlerId {
    Bytecode = 0,
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

impl traits::SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.selector)?;

        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Bytecode => {
                let key = keys::evm::account::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key_ptr(&MaybeRelocatable::Int(key.hash()), self.dict_manager.clone())?;
                let address = vm.get_maybe(&ptr).unwrap();
                println!("{:?}", key);
                println!("{:?}", ptr);
                retdata_end = BytecodeLeWords::from_memory(vm, address.get_relocatable().unwrap())?.to_memory(vm, retdata_end)?;
                println!("dupa");
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
