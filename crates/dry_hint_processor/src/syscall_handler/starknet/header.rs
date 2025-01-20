use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use syscall_handler::traits::CallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult};

use std::env;
use types::{
    cairo::{
        starknet::header::{Block, FunctionId, StarknetBlock},
        structs::Felt,
        traits::CairoType,
    },
    keys::starknet::header::{CairoKey, Key},
    FEEDER_GATEWAY,
};

use crate::syscall_handler::{STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID};

#[derive(Debug, Default)]
pub struct HeaderCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = Felt;

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
        let base_url =
            env::var(FEEDER_GATEWAY).map_err(|e| SyscallExecutionError::InternalError(format!("Missing FEEDER_GATEWAY env var: {}", e).into()))?;

        // Feeder Gateway rejects the requests if this header is not set
        let host_header = match key.chain_id {
            STARKNET_MAINNET_CHAIN_ID => "alpha-mainnet.starknet.io",
            STARKNET_TESTNET_CHAIN_ID => "alpha-sepolia.starknet.io",
            _ => return Err(SyscallExecutionError::InternalError(format!("Unknown chain id: {}", key.chain_id).into())),
        };

        let request = reqwest::Client::new()
            .get(format!("{}get_block", base_url))
            .header("Host", host_header)
            .query(&[("blockNumber", key.block_number.to_string())]);

        let response = request
            .send()
            .await
            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

        let block_data: Block = match response.status().is_success() {
            true => response.json().await,
            false => {
                let status = response.status();
                let error_body = response.text().await.unwrap_or_default();
                return Err(SyscallExecutionError::InternalError(
                    format!("Request failed ({}): {}", status, error_body).into(),
                ));
            }
        }
        .map_err(|e| SyscallExecutionError::InternalError(format!("Failed to parse block data: {}", e).into()))?;

        let sn_block: StarknetBlock = block_data.into();

        let field = sn_block.handle(function_id);
        println!("Field: {:?}", field);

        Ok(field)
    }
}
