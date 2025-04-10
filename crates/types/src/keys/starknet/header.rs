use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};
use starknet_crypto::poseidon_hash_many;

use super::{ChainIdentifiable, KeyError};
use crate::cairo::traits::CairoType;

#[derive(Debug, Clone)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
}

impl CairoKey {
    pub fn hash(&self) -> Felt252 {
        poseidon_hash_many(&[self.chain_id, self.block_number])
    }
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            chain_id: *vm.get_integer((address + 0)?)?,
            block_number: *vm.get_integer((address + 1)?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        Ok((address + 2)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    pub chain_id: u128,
    pub block_number: u64,
}

impl ChainIdentifiable for Key {
    fn chain_id(&self) -> u128 {
        self.chain_id
    }
}

impl TryFrom<CairoKey> for Key {
    type Error = KeyError;
    fn try_from(value: CairoKey) -> Result<Self, Self::Error> {
        Ok(Self {
            chain_id: value.chain_id.try_into().map_err(|e| KeyError::ConversionError(format!("{}", e)))?,
            block_number: value
                .block_number
                .try_into()
                .map_err(|e| KeyError::ConversionError(format!("{}", e)))?,
        })
    }
}
