use cairo_vm::types::relocatable::Relocatable;
use cairo_vm::vm::errors::memory_errors::MemoryError;
use cairo_vm::vm::vm_core::VirtualMachine;

pub trait CairoType: Sized {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError>;
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError>;
    fn n_fields() -> usize;
}