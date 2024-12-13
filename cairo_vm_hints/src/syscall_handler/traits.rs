use crate::cairo_types::traits::CairoType;

use super::utils::SyscallResult;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};

pub trait CallHandler {
    type Key;
    type Id;
    type CallHandlerResult: CairoType;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key>;
    fn derive_id(selector: Felt252) -> SyscallResult<Self::Id>;
    fn handle(key: Self::Key, function_id: Self::Id) -> SyscallResult<Self::CallHandlerResult>;
}
