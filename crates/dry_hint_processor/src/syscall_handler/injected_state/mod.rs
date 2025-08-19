use std::collections::HashMap;

use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use state_server::api::{
    id_to_root::{GetRootRequest, GetRootResponse},
    read::{ReadRequest, ReadResponse},
    root_to_id::{GetIdRequest, GetIdResponse},
    write::{WriteRequest, WriteResponse},
};
use strum_macros::FromRepr;
use syscall_handler::{traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
    },
    keys,
    proofs::injected_state::Action,
    Felt252,
};

pub mod id_to_root;
pub mod read;
pub mod root_to_id;
pub mod write;

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    Read = 0,
    Write = 1,
    IdToRoot = 2,
    RootToId = 3,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CallContractHandler {
    pub key_set: HashMap<Felt252, Vec<Action>>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let call_handler_id = CallHandlerId::try_from(request.selector)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Read => {
                let client = reqwest::Client::new();

                let key = keys::injected_state::read::CairoKey::from_memory(vm, request.calldata_start)?;
                let request_payload = ReadRequest {
                    trie_root: pathfinder_crypto::Felt::from(key.trie_root.to_bytes_be()),
                    key: pathfinder_crypto::Felt::from(key.key.to_bytes_be()),
                };
                let endpoint = format!("{}/read", "0.0.0.0:3000");

                let response = client
                    .get(endpoint)
                    .query(&request_payload)
                    .send()
                    .await
                    .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                match response.status() {
                    StatusCode::OK => {
                        let response = response
                            .json::<ReadResponse>()
                            .await
                            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                        let result = read::Response {
                            exist: response.value.is_some().into(),
                            value: Felt252::from_bytes_be(&response.value.unwrap_or_default().to_be_bytes()),
                        };

                        retdata_end = result.to_memory(vm, retdata_end)?;
                    }
                    status => {
                        let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
                        Err(SyscallExecutionError::InternalError(
                            format!("Network request failed: {}: {}", status, error_text).into(),
                        ))?;
                    }
                }
            }
            CallHandlerId::Write => {
                let client = reqwest::Client::new();

                let key = keys::injected_state::write::CairoKey::from_memory(vm, request.calldata_start)?;
                let request_payload = WriteRequest {
                    trie_root: pathfinder_crypto::Felt::from(key.trie_root.to_bytes_be()),
                    key: pathfinder_crypto::Felt::from(key.key.to_bytes_be()),
                    value: pathfinder_crypto::Felt::from(key.value.to_bytes_be()),
                };
                let endpoint = format!("{}/write", "0.0.0.0:3000");

                let response = client
                    .get(endpoint)
                    .query(&request_payload)
                    .send()
                    .await
                    .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                match response.status() {
                    StatusCode::OK => {
                        let response = response
                            .json::<WriteResponse>()
                            .await
                            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                        let result = write::Response {
                            exist: response.value.is_some().into(),
                            value: Felt252::from_bytes_be(&response.value.unwrap_or_default().to_be_bytes()),
                            trie_root: Felt252::from_bytes_be(&response.trie_root.to_be_bytes()),
                        };

                        retdata_end = result.to_memory(vm, retdata_end)?;
                    }
                    status => {
                        let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
                        Err(SyscallExecutionError::InternalError(
                            format!("Network request failed: {}: {}", status, error_text).into(),
                        ))?;
                    }
                }
            }
            CallHandlerId::RootToId => {
                let client = reqwest::Client::new();

                let key = keys::injected_state::root_to_id::CairoKey::from_memory(vm, request.calldata_start)?;
                let request_payload = GetIdRequest {
                    trie_root: pathfinder_crypto::Felt::from(key.trie_root.to_bytes_be()),
                };
                let endpoint = format!("{}/get_id_by_trie_root", "0.0.0.0:3000");

                let response = client
                    .get(endpoint)
                    .query(&request_payload)
                    .send()
                    .await
                    .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                match response.status() {
                    StatusCode::OK => {
                        let response = response
                            .json::<GetIdResponse>()
                            .await
                            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                        let result = root_to_id::Response {
                            trie_id: response.trie_id.into(),
                        };

                        retdata_end = result.to_memory(vm, retdata_end)?;
                    }
                    status => {
                        let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
                        Err(SyscallExecutionError::InternalError(
                            format!("Network request failed: {}: {}", status, error_text).into(),
                        ))?;
                    }
                }
            }
            CallHandlerId::IdToRoot => {
                let client = reqwest::Client::new();

                let key = keys::injected_state::id_to_root::CairoKey::from_memory(vm, request.calldata_start)?;
                let request_payload = GetRootRequest {
                    trie_id: key.trie_id.try_into().unwrap(),
                };
                let endpoint = format!("{}/get_trie_root_by_id", "0.0.0.0:3000");

                let response = client
                    .get(endpoint)
                    .query(&request_payload)
                    .send()
                    .await
                    .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                match response.status() {
                    StatusCode::OK => {
                        let response = response
                            .json::<GetRootResponse>()
                            .await
                            .map_err(|e| SyscallExecutionError::InternalError(format!("Network request failed: {}", e).into()))?;

                        let result = id_to_root::Response {
                            trie_root: Felt252::from_bytes_be(&response.trie_root.to_be_bytes()),
                        };

                        retdata_end = result.to_memory(vm, retdata_end)?;
                    }
                    status => {
                        let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
                        Err(SyscallExecutionError::InternalError(
                            format!("Network request failed: {}: {}", status, error_text).into(),
                        ))?;
                    }
                }
            }
        }

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        unreachable!()
    }
}

impl TryFrom<Felt252> for CallHandlerId {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        Self::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })
    }
}
