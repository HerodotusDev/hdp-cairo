use crate::syscall_handler::{
    keys::{
        storage::{CairoKey, Key},
        FetchValue,
    },
    traits::CallHandler,
    utils::{SyscallExecutionError, SyscallResult},
};
use alloy::providers::{Provider, RootProvider};
use alloy::transports::http::{Client, Http};
use alloy::{
    hex::FromHex,
    primitives::{Address, BlockNumber, ChainId, StorageKey, StorageValue},
    transports::http::reqwest::Url,
};
use cairo_types::{
    evm::storage::{CairoStorage, FunctionId},
    structs::Uint256,
    traits::CairoType,
};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use provider::RPC;
use serde::{Deserialize, Serialize};
use std::env;

pub struct StorageCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for StorageCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Uint256;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields())?;
        ret.try_into()
    }

    fn derive_id(selector: Felt252) -> SyscallResult<Self::Id> {
        Self::Id::from_repr(selector.try_into().map_err(|e| SyscallExecutionError::InvalidSyscallInput {
            input: selector,
            info: format!("{}", e),
        })?)
        .ok_or(SyscallExecutionError::InvalidSyscallInput {
            input: selector,
            info: "Invalid function identifier".to_string(),
        })
    }

    fn handle(key: Self::Key, function_id: Self::Id) -> SyscallResult<Self::CallHandlerResult> {
        Ok(CairoStorage::from(key.fetch_value()?).handle(function_id))
    }
}
