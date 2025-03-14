use std::env;

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
        evm::receipt::{CairoReceiptWithBloom, FunctionId},
        traits::CairoType,
    },
    keys::evm::receipt::{CairoKey, Key},
    RPC_URL_ETHEREUM,
};

#[derive(Debug, Default)]
pub struct ReceiptCallHandler;

impl CallHandler for ReceiptCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Vec<Felt252>;

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
        let provider = RootProvider::<Ethereum>::new_http(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap());

        let receipts = provider
            .get_block_receipts(BlockId::Number(BlockNumberOrTag::Number(key.block_number)))
            .await
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?
            .unwrap();

        let tx_idx: usize = key.transaction_index.try_into().unwrap();
        let receipt = match receipts[tx_idx].inner.as_receipt_with_bloom() {
            Some(receipt) => CairoReceiptWithBloom::from(receipt.clone()),
            None => return Err(SyscallExecutionError::InternalError("Receipt not found".into())),
        };

        Ok(receipt.handle(function_id))
    }
}
