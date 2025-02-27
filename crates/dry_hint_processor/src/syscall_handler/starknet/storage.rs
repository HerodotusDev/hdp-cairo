use std::env;

use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use starknet::{
    core::types::BlockId,
    providers::{
        jsonrpc::{HttpTransport, JsonRpcClient},
        Provider, Url,
    },
};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{evm::storage::FunctionId, structs::CairoFelt, traits::CairoType},
    keys::starknet::storage::{CairoKey, Key},
    RPC_URL_STARKNET,
};

#[derive(Debug, Default)]
pub struct StorageCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for StorageCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = CairoFelt;

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
        let provider = JsonRpcClient::new(HttpTransport::new(Url::parse(&env::var(RPC_URL_STARKNET).unwrap()).unwrap()));
        let block_id = BlockId::Number(key.block_number);
        let value = match function_id {
            FunctionId::Storage => provider
                .get_storage_at::<Felt252, Felt252, BlockId>(key.address, key.storage_slot, block_id)
                .await
                .map(CairoFelt::from),
        }
        .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

        Ok(value)
    }
}
