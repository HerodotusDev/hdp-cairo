use alloy::{
    consensus::{Receipt, ReceiptWithBloom},
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use std::env;
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        evm::receipt::{CairoReceiptWithBloom, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    keys::receipt::CairoKey,
    RPC,
};

#[derive(Debug, Default)]
pub struct ReceiptCallHandler;

impl CallHandler for ReceiptCallHandler {
    type Key = CairoKey;
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
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());

        let mut tx_hash_bytes = [0u8; 32];
        tx_hash_bytes[0..16].copy_from_slice(&key.tx_hash_high.to_bytes_be());
        tx_hash_bytes[16..32].copy_from_slice(&key.tx_hash_low.to_bytes_be());

        let receipt = provider
            .get_transaction_receipt(tx_hash_bytes.into())
            .await
            .map(|receipt| match receipt {
                Some(receipt) => CairoReceiptWithBloom::from(receipt),
                None => CairoReceiptWithBloom::from(ReceiptWithBloom::from(Receipt::default())),
            })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

        Ok(receipt.handle(function_id))
    }
}
