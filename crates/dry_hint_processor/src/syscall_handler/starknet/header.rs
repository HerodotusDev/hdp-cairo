use std::env;

use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use reqwest::Url;
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        starknet::header::{FunctionId, StarknetBlock},
        structs::Felt,
        traits::CairoType,
    },
    keys::starknet::header::{CairoKey, Key},
    HERODOTUS_STAGING_INDEXER,
};
use serde_json::Value;

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
        // Parse base URL from environment variable
        let base_url = Url::parse(&env::var(HERODOTUS_STAGING_INDEXER).unwrap()).unwrap();

        // Build and execute request
        let response = reqwest::Client::new()
            .get(format!("{}blocks", base_url))
            .query(&[
                ("chain_id", key.chain_id.to_string()),
                ("from_block_number_inclusive", key.block_number.to_string()),
                ("to_block_number_inclusive", key.block_number.to_string()),
                ("hashing_function", "poseidon".to_string()),
            ])
            .send()
            .await
            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

        // Parse JSON response and extract fields
        let blocks: Value = response
            .json()
            .await
            .map_err(|e| SyscallExecutionError::InternalError(format!("Failed to parse JSON response: {}", e).into()))?;

        // Extract and convert block fields
        let fields = blocks["data"]
            .get(0)
            .and_then(|block| block["block_header"]["Fields"].as_array())
            .ok_or_else(|| SyscallExecutionError::InternalError("Invalid response format".into()))?
            .iter()
            .map(|v| {
                v.as_str()
                    .ok_or_else(|| SyscallExecutionError::InternalError("Invalid field format".into()))
                    .and_then(|hex_str| {
                        Felt252::from_hex(hex_str)
                            .map_err(|e| SyscallExecutionError::InternalError(format!("Invalid field value: {}", e).into()))
                    })
            })
            .collect::<Result<Vec<Felt252>, SyscallExecutionError>>()?;

        // Create block and handle function
        Ok(StarknetBlock::from_hash_fields(fields).handle(function_id))
    }
}
