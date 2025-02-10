use alloy::primitives::{Address, BlockNumber, StorageKey};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};
use starknet_crypto::poseidon_hash_many;

use super::KeyError;
use crate::cairo::traits::CairoType;

#[derive(Debug, Clone)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
    address: Felt252,
    storage_slot_high: Felt252,
    storage_slot_low: Felt252,
}

impl CairoKey {
    pub fn hash(&self) -> Felt252 {
        poseidon_hash_many(&[
            self.chain_id,
            self.block_number,
            self.address,
            self.storage_slot_high,
            self.storage_slot_low,
        ])
    }
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            chain_id: *vm.get_integer((address + 0)?)?,
            block_number: *vm.get_integer((address + 1)?)?,
            address: *vm.get_integer((address + 2)?)?,
            storage_slot_high: *vm.get_integer((address + 3)?)?,
            storage_slot_low: *vm.get_integer((address + 4)?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        vm.insert_value((address + 2)?, self.address)?;
        vm.insert_value((address + 3)?, self.storage_slot_high)?;
        vm.insert_value((address + 4)?, self.storage_slot_low)?;
        Ok((address + 5)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(5)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    pub chain_id: u128,
    pub block_number: BlockNumber,
    pub address: Address,
    pub storage_slot: StorageKey,
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
            address: Address::try_from(value.address.to_biguint().to_bytes_be().as_slice())
                .map_err(|e| KeyError::ConversionError(format!("{}", e)))?,
            storage_slot: StorageKey::from(
                &[
                    &value.storage_slot_high.to_bytes_be().as_slice()[16..],
                    &value.storage_slot_low.to_bytes_be().as_slice()[16..],
                ]
                .concat()
                .try_into()
                .map_err(|_| KeyError::ConversionError("Failed to form StorageKey".into()))?,
            ),
        })
    }
}
