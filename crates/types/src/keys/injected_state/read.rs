use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use starknet_crypto::poseidon_hash_many;

use crate::cairo::traits::CairoType;

#[derive(Debug, Clone)]
pub struct CairoKey {
    pub trie_root: Felt252,
    pub key: Felt252,
}

impl CairoKey {
    pub fn hash(&self) -> Felt252 {
        poseidon_hash_many(&[self.trie_root, self.key])
    }
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            trie_root: *vm.get_integer((address + 0)?)?,
            key: *vm.get_integer((address + 1)?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.trie_root)?;
        vm.insert_value((address + 1)?, self.key)?;
        Ok((address + 2)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}
