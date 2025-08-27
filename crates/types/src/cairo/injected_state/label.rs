use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};

use crate::cairo::traits::CairoType;

#[derive(Default, Debug, Clone)]
pub struct Response {
    pub trie_root: Felt252,
    pub exists: Felt252,
}

impl CairoType for Response {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let trie_root = *vm.get_integer((address + 0)?)?;
        let exists = *vm.get_integer((address + 1)?)?;
        Ok(Self { trie_root, exists })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.trie_root)?;
        vm.insert_value((address + 1)?, self.exists)?;
        Ok((address + 2)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}
