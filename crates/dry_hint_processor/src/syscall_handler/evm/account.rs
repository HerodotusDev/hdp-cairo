use std::env;

use alloy::{
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{evm::account::FunctionId, structs::Uint256, traits::CairoType},
    keys::evm::account::{CairoKey, Key},
    RPC_URL_ETHEREUM,
};

#[derive(Debug, Default)]
pub struct AccountCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for AccountCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Uint256;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields(vm, *ptr)?)?;
        ret.try_into()
            .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))
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
        let value = match function_id {
            FunctionId::Balance => provider
                .get_balance(key.address)
                .block_id(key.block_number.into())
                .await
                .map(Uint256::from),
            FunctionId::Nonce => provider
                .get_transaction_count(key.address)
                .block_id(key.block_number.into())
                .await
                .map(Uint256::from),
            FunctionId::StateRoot => provider
                .get_proof(key.address, vec![])
                .block_id(key.block_number.into())
                .await
                .map(|f| Uint256::from(f.storage_hash)),
            FunctionId::CodeHash => provider
                .get_proof(key.address, vec![])
                .block_id(key.block_number.into())
                .await
                .map(|f| Uint256::from(f.code_hash)),
        }
        .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        Ok(value)
    }
}
