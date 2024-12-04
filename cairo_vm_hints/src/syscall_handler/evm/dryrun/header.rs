use crate::cairo_types::evm::header::{CairoHeader, FunctionId};
use crate::cairo_types::structs::Uint256;
use crate::cairo_types::traits::CairoType;
use crate::provider::evm::traits::EVMProviderTrait;
use crate::provider::evm::EVMProvider;
use crate::syscall_handler::utils::{SyscallExecutionError, SyscallResult};
use crate::syscall_handler::{traits::CallHandler, Relocatable, VirtualMachine};
use alloy::primitives::BlockNumber;
use alloy::transports::http::reqwest::Url;
use cairo_type_derive::CairoType;
use cairo_type_derive::FieldOffsetGetters;
use cairo_vm::vm::errors::memory_errors::MemoryError;
use cairo_vm::Felt252;
use tokio::runtime::Handle;
use tokio::task;

pub struct HeaderCallHandler;

#[derive(FieldOffsetGetters, CairoType)]
pub struct Key {
    chain_id: Felt252,
    block_number: Felt252,
}

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
    type Key = Key;
    type Id = FunctionId;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = Self::Key::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Key::cairo_size())?;
        Ok(ret)
    }

    fn derive_id(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Id> {
        let felt = vm.get_integer(*ptr)?.into_owned();
        Self::Id::from_repr(felt.try_into().map_err(|e| SyscallExecutionError::InvalidSyscallInput {
            input: felt,
            info: format!("{}", e),
        })?)
        .ok_or(SyscallExecutionError::InvalidSyscallInput {
            input: felt,
            info: "Invalid function identifier".to_string(),
        })
    }

    fn handle(key: Self::Key, id: Self::Id) -> SyscallResult<Uint256> {
        let provider = EVMProvider::new(Url::parse("https://sepolia.ethereum.iosis.tech/").unwrap());

        let block_number: BlockNumber = key.block_number.try_into().map_err(|e| SyscallExecutionError::InvalidSyscallInput {
            input: key.block_number,
            info: format!("{}", e),
        })?;

        let block = task::block_in_place(move || Handle::current().block_on(async move { provider.get_block(block_number).await }))
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

        Ok(CairoHeader::from(block.header.inner).handle(id))
    }
}
