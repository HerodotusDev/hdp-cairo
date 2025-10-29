use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
    Felt252,
};
use syscall_handler::{memorizer::Memorizer, traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{new_syscalls::CairoVec, traits::CairoType, unconstrained_state::FunctionId},
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
    type CallHandlerResult = CairoVec;

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

    async fn handle(&mut self, key: Self::Key, function_id: Self::Id, vm: &VirtualMachine) -> SyscallResult<Self::CallHandlerResult> {
        let ptr = self
            .memorizer
            .read_key_ptr(&MaybeRelocatable::Int(key.hash()), self.dict_manager.clone())?;

        // data is the rlp-encoded receipt (injected by the verified mpt proof Cairo0 memorizer)
        let mut data = vm.get_integer(ptr)?.to_bytes_le().to_vec();

        // Max bytecode size is 24KB = 24 * 1024 bytes
        //? https://ethereum.org/developers/docs/smart-contracts/#limitations
        data.resize(24 * 1024, 0);

        // ! TODO: @beeinger - implement this, no idea how for now...

        unimplemented!();
    }
}
