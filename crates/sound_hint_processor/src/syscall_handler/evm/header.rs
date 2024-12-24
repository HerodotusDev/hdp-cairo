use crate::syscall_handler::Memorizer;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use syscall_handler::traits::CallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult};
use types::{
    cairo::{evm::header::FunctionId, structs::Uint256, traits::CairoType},
    keys::header::{CairoKey, Key},
};

#[derive(Debug)]
pub struct HeaderCallHandler {
    pub memorizer: Memorizer,
}

impl HeaderCallHandler {
    pub fn new(memorizer: Memorizer) -> Self {
        Self { memorizer }
    }
}

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Uint256;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields())?;
        ret.try_into().map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))
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

    fn handle(&mut self, _key: Self::Key, _function_id: Self::Id) -> SyscallResult<Self::CallHandlerResult> {
        Ok(Uint256::from(0_u64))
    }
}
