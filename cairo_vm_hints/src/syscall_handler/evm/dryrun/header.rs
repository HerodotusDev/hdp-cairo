use crate::syscall_handler::{
    traits::CallHandler,
    utils::{SyscallExecutionError, SyscallResult},
    Relocatable, VirtualMachine,
};
use crate::{
    cairo_types::{
        evm::header::{CairoHeader, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    syscall_handler::RPC,
};
use alloy::providers::{Provider, RootProvider};
use alloy::rpc::types::BlockTransactionsKind;
use alloy::transports::http::{Client, Http};
use alloy::{
    primitives::{BlockNumber, ChainId},
    transports::http::reqwest::Url,
};
use cairo_vm::{vm::errors::memory_errors::MemoryError, Felt252};
use std::env;

pub struct HeaderCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
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
        let block = runtime
            .block_on(async { provider.get_block_by_number(key.block_number.into(), BlockTransactionsKind::Hashes).await })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?
            .ok_or(SyscallExecutionError::InternalError("Block not found".into()))?;

        Ok(CairoHeader::from(block.header.inner).handle(function_id))
    }
}

#[derive(Debug)]
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

#[derive(Debug)]
pub struct Key {
    chain_id: ChainId,
    block_number: BlockNumber,
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
        })
    }
}
