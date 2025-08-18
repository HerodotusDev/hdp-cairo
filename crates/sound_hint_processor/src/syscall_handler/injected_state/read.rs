use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
};
use types::{cairo::traits::CairoType, Felt252};

#[derive(Default, Debug, Clone)]
pub struct Response {
    pub exists: Felt252,
    pub value: Felt252,
}

impl CairoType for Response {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let value = *vm.get_integer((address + 0)?)?;
        let exists = *vm.get_integer((address + 1)?)?;
        Ok(Self { value, exists })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.exists)?;
        vm.insert_value((address + 1)?, self.value)?;
        Ok((address + 2)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}
