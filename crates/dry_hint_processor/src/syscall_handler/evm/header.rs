use alloy::providers::{Provider, RootProvider};
use alloy::rpc::types::BlockTransactionsKind;
use alloy::transports::http::reqwest::Url;
use alloy::transports::http::{Client, Http};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use std::env;
use syscall_handler::traits::CallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        evm::header::{CairoHeader, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    keys::evm::header::{CairoKey, Key},
    RPC_URL_ETHEREUM,
};

#[derive(Debug, Default)]
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

    async fn handle(&mut self, key: Self::Key, function_id: Self::Id, _vm: &VirtualMachine) -> SyscallResult<Self::CallHandlerResult> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap());
        let value = provider
            .get_block_by_number(key.block_number.into(), BlockTransactionsKind::Hashes)
            .await
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?
            .ok_or(SyscallExecutionError::InternalError("Block not found".into()))?;
        Ok(CairoHeader::from(value.header.inner).handle(function_id))
    }
}
