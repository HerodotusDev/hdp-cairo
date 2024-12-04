use crate::cairo_types::traits::CairoType;

use super::utils::SyscallResult;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};

pub trait CallHandler {
    type Key;
    type Id;
    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key>;
    fn derive_id(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Id>;
    fn handle(key: Self::Key, id: Self::Id) -> SyscallResult<impl CairoType>;
}
