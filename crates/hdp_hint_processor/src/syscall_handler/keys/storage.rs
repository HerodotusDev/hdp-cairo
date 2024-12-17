use super::FetchValue;
use crate::syscall_handler::utils::SyscallExecutionError;
use alloy::{
    primitives::{Address, BlockNumber, ChainId, StorageKey, StorageValue},
    providers::{Provider, RootProvider},
    rpc::types::EIP1186AccountProofResponse,
    transports::http::Http,
};
use cairo_types::traits::CairoType;
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use provider::RPC;
use reqwest::{Client, Url};
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Debug)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
    address: Felt252,
    storage_slot_high: Felt252,
    storage_slot_low: Felt252,
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
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        vm.insert_value((address + 2)?, self.address)?;
        vm.insert_value((address + 2)?, self.storage_slot_high)?;
        vm.insert_value((address + 2)?, self.storage_slot_low)?;
        Ok(())
    }
    fn n_fields() -> usize {
        5
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    pub chain_id: ChainId,
    pub block_number: BlockNumber,
    pub address: Address,
    pub storage_slot: StorageKey,
}

impl FetchValue for Key {
    type Value = StorageValue;

    fn fetch_value(&self) -> Result<Self::Value, SyscallExecutionError> {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let value = runtime
            .block_on(async {
                provider
                    .get_storage_at(self.address, self.storage_slot.into())
                    .block_id(self.block_number.into())
                    .await
            })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        Ok(value)
    }
}

impl TryFrom<CairoKey> for Key {
    type Error = SyscallExecutionError;
    fn try_from(value: CairoKey) -> Result<Self, Self::Error> {
        Ok(Self {
            chain_id: value
                .chain_id
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            block_number: value
                .block_number
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            address: Address::try_from(value.address.to_biguint().to_bytes_be().as_slice())
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            storage_slot: StorageKey::from(
                &[
                    &value.storage_slot_high.to_bytes_be().as_slice()[16..],
                    &value.storage_slot_low.to_bytes_be().as_slice()[16..],
                ]
                .concat()
                .try_into()
                .map_err(|_| SyscallExecutionError::InternalError("Failed to form StorageKey".into()))?,
            ),
        })
    }
}
