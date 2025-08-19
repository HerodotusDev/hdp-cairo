use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
};
use types::{cairo::traits::CairoType, Felt252};

#[derive(Default, Debug, Clone)]
pub struct Response {
    pub trie_id: Felt252,
}

impl CairoType for Response {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let trie_id = *vm.get_integer((address + 0)?)?;
        Ok(Self { trie_id })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.trie_id)?;
        Ok((address + 1)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(1)
    }
}
