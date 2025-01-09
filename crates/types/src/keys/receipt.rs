use super::KeyError;
use crate::cairo::traits::CairoType;
use alloy::primitives::BlockNumber;
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};
use starknet_crypto::poseidon_hash_many;

#[derive(Debug, Clone)]
pub struct CairoKey {
    pub tx_hash_high: Felt252,
    pub tx_hash_low: Felt252,
    pub block_number: Felt252,
}

impl CairoKey {
    pub fn hash(&self) -> Felt252 {
        poseidon_hash_many(&[self.tx_hash_high, self.tx_hash_low, self.block_number])
    }
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, ptr: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            tx_hash_high: *vm.get_integer(ptr)?,
            tx_hash_low: *vm.get_integer((ptr + 1)?)?,
            block_number: *vm.get_integer((ptr + 2)?)?,
        })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.tx_hash_high)?;
        vm.insert_value((address + 1)?, self.tx_hash_low)?;
        vm.insert_value((address + 2)?, self.block_number)?;

        Ok(())
    }

    fn n_fields() -> usize {
        3
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    pub tx_hash_high: Felt252,
    pub tx_hash_low: Felt252,
    pub block_number: BlockNumber,
}

impl TryFrom<CairoKey> for Key {
    type Error = KeyError;
    fn try_from(value: CairoKey) -> Result<Self, Self::Error> {
        Ok(Self {
            tx_hash_high: value.tx_hash_high,
            tx_hash_low: value.tx_hash_low,
            block_number: value.block_number.try_into().map_err(|e| KeyError::ConversionError(format!("{}", e)))?,
        })
    }
}
