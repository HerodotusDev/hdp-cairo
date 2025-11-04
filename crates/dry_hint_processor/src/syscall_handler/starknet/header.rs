use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use indexer_client::{models::blocks, Indexer};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        starknet::header::{FunctionId, StarknetBlock},
        structs::CairoFelt,
        traits::CairoType,
    },
    keys::starknet::header::{CairoKey, Key},
};

#[derive(Debug, Default)]
pub struct HeaderCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
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
        let provider = Indexer::default();

        // Fetch proof response
        let response = provider
            .get_blocks(blocks::IndexerQuery::new(
                key.chain_id,
                key.block_number.into(),
                key.block_number.into(),
            ))
            .await
            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

        // Create block and handle function
        Ok(StarknetBlock::from_hash_fields(response.fields).handle(function_id))
    }
}
