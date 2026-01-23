use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};
use starknet_crypto::poseidon_hash_many;

use super::{ChainIdentifiable, KeyError, BLOCK_TX_LABEL};
use crate::{cairo::traits::CairoType, BlockNumber, ChainId, TransactionIndex};

#[derive(Debug, Clone)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
    transaction_index: Felt252,
}

impl CairoKey {
    pub fn hash(&self) -> Felt252 {
        poseidon_hash_many(&[self.chain_id, BLOCK_TX_LABEL, self.block_number, self.transaction_index])
    }
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, ptr: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            chain_id: *vm.get_integer((ptr + 0)?)?,
            block_number: *vm.get_integer((ptr + 1)?)?,
            transaction_index: *vm.get_integer((ptr + 2)?)?,
        })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        vm.insert_value((address + 2)?, self.transaction_index)?;
        Ok((address + 3)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(3)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    pub chain_id: ChainId,
    pub block_number: BlockNumber,
    pub transaction_index: TransactionIndex,
}

impl ChainIdentifiable for Key {
    fn chain_id(&self) -> ChainId {
        self.chain_id
    }
}

impl TryFrom<CairoKey> for Key {
    type Error = KeyError;
    fn try_from(value: CairoKey) -> Result<Self, Self::Error> {
        Ok(Self {
            chain_id: value.chain_id.try_into().map_err(|_| KeyError::FeltConversionFailed {
                field: "chain_id",
                value: value.chain_id.to_string(),
            })?,
            block_number: value.block_number.try_into().map_err(|_| KeyError::FeltConversionFailed {
                field: "block_number",
                value: value.block_number.to_string(),
            })?,
            transaction_index: value.transaction_index.try_into().map_err(|_| KeyError::FeltConversionFailed {
                field: "transaction_index",
                value: value.transaction_index.to_string(),
            })?,
        })
    }
}
