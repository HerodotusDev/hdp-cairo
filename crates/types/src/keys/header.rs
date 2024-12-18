use super::{account, storage, KeyError};
use crate::cairo::traits::CairoType;
use alloy::primitives::{BlockNumber, ChainId};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            chain_id: *vm.get_integer((address + 0)?)?,
            block_number: *vm.get_integer((address + 1)?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        Ok(())
    }
    fn n_fields() -> usize {
        2
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    pub chain_id: ChainId,
    pub block_number: BlockNumber,
}

impl From<account::Key> for Key {
    fn from(value: account::Key) -> Self {
        Self {
            chain_id: value.chain_id,
            block_number: value.block_number,
        }
    }
}

impl From<storage::Key> for Key {
    fn from(value: storage::Key) -> Self {
        Self {
            chain_id: value.chain_id,
            block_number: value.block_number,
        }
    }
}

impl TryFrom<CairoKey> for Key {
    type Error = KeyError;
    fn try_from(value: CairoKey) -> Result<Self, Self::Error> {
        Ok(Self {
            chain_id: value.chain_id.try_into().map_err(|e| KeyError::ConversionError(format!("{}", e)))?,
            block_number: value.block_number.try_into().map_err(|e| KeyError::ConversionError(format!("{}", e)))?,
        })
    }
}
