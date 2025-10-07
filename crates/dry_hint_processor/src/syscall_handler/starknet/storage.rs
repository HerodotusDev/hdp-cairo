use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use starknet::{
    core::types::{BlockId, Felt},
    providers::{
        jsonrpc::{HttpTransport, JsonRpcClient},
        Provider, Url,
    },
};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{evm::storage::FunctionId, structs::CairoFelt, traits::CairoType},
    keys::starknet::{
        get_corresponding_rpc_url,
        storage::{CairoKey, Key},
    },
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
        let rpc_url = get_corresponding_rpc_url(&key).map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        let provider = JsonRpcClient::new(HttpTransport::new(Url::parse(&rpc_url).unwrap()));
        let block_id = BlockId::Number(key.block_number);
        let value = match function_id {
            FunctionId::Storage => provider
                .get_storage_at::<Felt, Felt, BlockId>(
                    Felt::from_bytes_be(&key.address.to_bytes_be()),
                    Felt::from_bytes_be(&key.storage_slot.to_bytes_be()),
                    block_id,
                )
                .await
                .map(|f| CairoFelt::from(Felt252::from_bytes_be(&f.to_bytes_be()))),
        }
        .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

        Ok(value)
    }
}
