use alloy::providers::{Provider, RootProvider};
use alloy::rpc::types::BlockTransactionsKind;
use alloy::transports::http::reqwest::Url;
use alloy::transports::http::{Client, Http};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use syscall_handler::traits::CallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult};
use std::env;
use types::{
    cairo::{
        evm::header::{CairoHeader, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    keys::header::{CairoKey, Key},
    RPC,
};

pub struct HeaderCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Uint256;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields())?;
        ret.try_into().map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))
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
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let value = runtime
            .block_on(async { provider.get_block_by_number(key.block_number.into(), BlockTransactionsKind::Hashes).await })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?
            .ok_or(SyscallExecutionError::InternalError("Block not found".into()))?;
        Ok(CairoHeader::from(value.header.inner).handle(function_id))
    }
}
