use std::{cell::RefCell, collections::HashMap, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use starknet_crypto::poseidon_hash_single;
use state_server::api::{
    read::{ReadRequest, ReadResponse},
    write::{WriteRequest, WriteResponse},
};
use strum_macros::FromRepr;
use syscall_handler::{memorizer::Memorizer, traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
    },
    keys,
    proofs::injected_state::Action,
    Felt252,
};

pub mod label;
pub mod read;
pub mod write;

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    Read = 0,
    Write = 1,
    Label = 2,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CallContractHandler {
    pub key_set: HashMap<Felt252, Vec<Action>>,
    #[serde(skip)]
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let call_handler_id = CallHandlerId::try_from(request.selector)?;

        let mut calldata = request.calldata_start;
        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Read => {
                let client = reqwest::Client::new();

                let key = keys::injected_state::read::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_single(key.trie_label)),
                    self.dict_manager.clone(),
                )?;
                let trie_root = vm.get_integer(ptr)?;

                let request_payload = ReadRequest {
                    trie_root: pathfinder_crypto::Felt::from(trie_root.to_bytes_be()),
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

                let key = keys::injected_state::write::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_single(key.trie_label)),
                    self.dict_manager.clone(),
                )?;
                let trie_root = vm.get_integer(ptr)?;

                let request_payload = WriteRequest {
                    trie_root: pathfinder_crypto::Felt::from(trie_root.to_bytes_be()),
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

                        memorizer.set_key(
                            &MaybeRelocatable::Int(poseidon_hash_single(key.trie_label)),
                            &MaybeRelocatable::Int(Felt252::from_bytes_be(&response.trie_root.to_be_bytes())),
                            self.dict_manager.clone(),
                        )?;

                        let result: write::Response = write::Response {
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
            CallHandlerId::Label => {
                let key = keys::injected_state::label::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_single(key.trie_label)),
                    self.dict_manager.clone(),
                )?;

                let result: label::Response = label::Response {
                    trie_root: *vm.get_integer(ptr)?,
                };

                retdata_end = result.to_memory(vm, retdata_end)?;
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
