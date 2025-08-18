use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
};
use types::{cairo::traits::CairoType, Felt252};

#[derive(Default, Debug, Clone)]
pub struct Response {
    pub prev_value: Felt252,
    pub new_root: Felt252,
}

impl CairoType for Response {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let prev_value = *vm.get_integer((address + 0)?)?;
        let new_root = *vm.get_integer((address + 1)?)?;
        Ok(Self { prev_value, new_root })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.prev_value)?;
        vm.insert_value((address + 1)?, self.new_root)?;
        Ok((address + 2)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}
