use alloy::{
    eips::{BlockId, BlockNumberOrTag},
    network::Ethereum,
    providers::{Provider, RootProvider},
    transports::http::reqwest::Url,
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        evm::transaction::{CairoTransaction, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    keys::evm::{
        get_corresponding_rpc_url,
        transaction::{CairoKey, Key},
    },
};

#[derive(Debug, Default)]
pub struct TransactionCallHandler;

impl CallHandler for TransactionCallHandler {
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
        let rpc_url = get_corresponding_rpc_url(&key).map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        let provider = RootProvider::<Ethereum>::new_http(Url::parse(&rpc_url).unwrap());

        let block = provider
            .get_block(BlockId::Number(BlockNumberOrTag::Number(key.block_number)))
            .full()
            .await
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?
            .unwrap();
        let tx = block
            .transactions
            .txns()
            .nth(key.transaction_index.try_into().unwrap())
            .ok_or_else(|| SyscallExecutionError::InternalError("Transaction index out of bounds".into()))?;
        let cairo_tx = CairoTransaction::from(tx.clone());

        Ok(cairo_tx.handle(function_id))
    }
}
