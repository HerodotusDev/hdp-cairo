use crate::{
    cairo_types::traits::CairoType,
    hint_processor::models::proofs::{self, mpt::MPTProof},
    syscall_handler::{utils::SyscallExecutionError, RPC},
};
use alloy::{
    consensus::Account,
    primitives::{Address, BlockNumber, ChainId},
    providers::{Provider, RootProvider},
    rpc::types::EIP1186AccountProofResponse,
    transports::http::Http,
};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use reqwest::{Client, Url};
use serde::{Deserialize, Serialize};
use std::env;

use super::FetchValue;

#[derive(Debug)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
    address: Felt252,
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            chain_id: *vm.get_integer((address + 0)?)?,
            block_number: *vm.get_integer((address + 1)?)?,
            address: *vm.get_integer((address + 2)?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        vm.insert_value((address + 2)?, self.address)?;
        Ok(())
    }
    fn n_fields() -> usize {
        3
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    chain_id: ChainId,
    block_number: BlockNumber,
    address: Address,
}

impl FetchValue for Key {
    type Value = Account;

    fn fetch_value(&self) -> Result<Self::Value, SyscallExecutionError> {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let value = runtime
            .block_on(async { provider.get_account(self.address).block_id(self.block_number.into()).await })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        Ok(value)
    }

    // fn fetch_proof(&self) -> Result<Self::Proof, SyscallExecutionError> {
    //     let runtime = tokio::runtime::Runtime::new().unwrap();
    //     let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
    //     let value = runtime
    //         .block_on(async { provider.get_proof(self.address, vec![]).block_id(self.block_number.into()).await })
    //         .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
    //     Ok(Self::Proof::new(
    //         value.address,
    //         vec![MPTProof::new(self.block_number, value.account_proof)],
    //     ))
    // }
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
        })
    }
}
