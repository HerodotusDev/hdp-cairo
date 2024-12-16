use crate::syscall_handler::{
    keys::{
        header::{CairoKey, Key},
        FetchValue,
    },
    traits::CallHandler,
    utils::{SyscallExecutionError, SyscallResult},
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
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};
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
        Ok(CairoHeader::from(key.fetch_value()?.header.inner).handle(function_id))
    }
}
