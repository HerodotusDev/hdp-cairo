use crate::syscall_handler::{
    traits::CallHandler,
    utils::{SyscallExecutionError, SyscallResult},
};
use crate::{
    cairo_types::{
        evm::account::{CairoAccount, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    syscall_handler::RPC,
};
use alloy::providers::{Provider, RootProvider};
use alloy::transports::http::{Client, Http};
use alloy::{
    hex::FromHex,
    primitives::{Address, BlockNumber, ChainId},
    transports::http::reqwest::Url,
};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};
use std::env;

pub struct AccountCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for AccountCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Uint256;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields())?;
        ret.try_into()
    }

    fn derive_id(selector: Felt252) -> SyscallResult<Self::Id> {
        Self::Id::try_from(selector)
    }

    fn handle(key: Self::Key, function_id: Self::Id) -> SyscallResult<Self::CallHandlerResult> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let account = runtime
            .block_on(async { provider.get_account(key.address).block_id(key.block_number.into()).await })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

        Ok(CairoAccount::from(account).handle(function_id))
    }
}

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
