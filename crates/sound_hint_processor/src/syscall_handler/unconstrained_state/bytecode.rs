use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
    Felt252,
};
use syscall_handler::{memorizer::Memorizer, traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        traits::CairoType,
        unconstrained_state::{bytecode::BytecodeLeWords, FunctionId},
    },
    keys::evm::account::CairoKey,
};

#[derive(Debug)]
pub struct BytecodeCallHandler {
    pub memorizer: Memorizer,
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl BytecodeCallHandler {
    pub fn new(memorizer: Memorizer, dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { memorizer, dict_manager }
    }
}

#[allow(refining_impl_trait)]
impl CallHandler for BytecodeCallHandler {
    type Key = CairoKey;
    type Id = FunctionId;
    type CallHandlerResult = BytecodeLeWords;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields(vm, *ptr)?)?;
        Ok(ret)
    }

    fn derive_id(selector: Felt252) -> SyscallResult<Self::Id> {
        Self::Id::from_repr(selector.try_into().map_err(|e| SyscallExecutionError::InvalidSyscallInput {
            input: selector,
            info: format!("{}", e),
        })?)
        .ok_or(SyscallExecutionError::InvalidSyscallInput {
            input: selector,
            info: "Invalid function identifier".to_string(),
        })
    }

    // TODO: @beeinger - function_id is not used for bytecode, do we get rid of it?
    async fn handle(&mut self, key: Self::Key, _function_id: Self::Id, vm: &VirtualMachine) -> SyscallResult<Self::CallHandlerResult> {
        let ptr = self
            .memorizer
            .read_key_ptr(&MaybeRelocatable::Int(key.hash()), self.dict_manager.clone())?;

        Ok(BytecodeLeWords::from_memory(vm, ptr)?)
    }
}
