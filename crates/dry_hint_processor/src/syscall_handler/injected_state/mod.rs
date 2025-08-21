use std::{cell::RefCell, collections::HashMap, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
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
    proofs::injected_state::{Action, ActionRead, ActionWrite},
    Felt252,
};

pub mod label;
pub mod read;
pub mod write;

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    ReadTrieRoot = 0,
    Read = 1,
    Write = 2,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CacheKey {
    trie_label: Felt252,
    key: Felt252,
}

#[derive(Debug, Clone)]
pub struct CacheEntry {
    exists: bool,
    value: Felt252,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CallContractHandler {
    pub key_set: HashMap<Felt252, Vec<Action>>,
    #[serde(skip)]
    pub dict_manager: Rc<RefCell<DictManager>>,
    #[serde(skip)]
    pub read_cache: HashMap<CacheKey, CacheEntry>,
}

impl CallContractHandler {
    fn get_base_url() -> String {
        std::env::var("INJECTED_STATE_BASE_URL").unwrap_or_else(|_| "http://0.0.0.0:3000".to_string())
    }

    async fn get_trie_root(&self, memorizer: &Memorizer, label: Felt252) -> Result<Option<Felt252>, HintError> {
        let key = MaybeRelocatable::Int(poseidon_hash_single(label));
        match memorizer.read_key_int(&key, self.dict_manager.clone()) {
            Ok(trie_root) if trie_root == Felt252::MAX => Ok(None),
            Ok(trie_root) => Ok(Some(trie_root)),
            Err(ref e) if matches!(e, HintError::NoValueForKey(_)) => Ok(None),
            Err(e) => return Err(e),
        }
    }

    fn get_from_cache(&self, trie_label: Felt252, key: Felt252) -> Option<CacheEntry> {
        let cache_key = CacheKey { trie_label, key };
        self.read_cache.get(&cache_key).cloned()
    }

    fn insert_to_cache(&mut self, trie_label: Felt252, key: Felt252, exists: bool, value: Felt252) {
        let cache_key = CacheKey { trie_label, key };
        let cache_entry = CacheEntry { exists, value };
        self.read_cache.insert(cache_key, cache_entry);
    }

    fn update_cache_on_write(&mut self, trie_label: Felt252, key: Felt252, exists: bool, value: Felt252) {
        self.insert_to_cache(trie_label, key, exists, value);
    }

    fn record_read_action(&mut self, trie_label: Felt252, trie_root: Felt252, key: Felt252) {
        let action = Action::Read(ActionRead {
            trie_root: pathfinder_crypto::Felt::from(trie_root.to_bytes_be()),
            key: pathfinder_crypto::Felt::from(key.to_bytes_be()),
        });
        self.key_set.entry(trie_label).or_insert_with(Vec::new).push(action);
    }

    fn record_write_action(&mut self, trie_label: Felt252, trie_root: Felt252, key: Felt252, value: Felt252) {
        let action = Action::Write(ActionWrite {
            trie_root: pathfinder_crypto::Felt::from(trie_root.to_bytes_be()),
            key: pathfinder_crypto::Felt::from(key.to_bytes_be()),
            value: pathfinder_crypto::Felt::from(value.to_bytes_be()),
        });
        self.key_set.entry(trie_label).or_insert_with(Vec::new).push(action);
    }
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
            CallHandlerId::ReadTrieRoot => {
                let key = keys::injected_state::label::CairoKey::from_memory(vm, calldata)?;
                let trie_root = self.get_trie_root(&memorizer, key.trie_label).await?;
                let result = label::Response {
                    trie_root: trie_root.unwrap_or(Felt252::ZERO),
                    exists: trie_root.is_some().into(),
                };

                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Read => {
                let key = keys::injected_state::read::CairoKey::from_memory(vm, calldata)?;

                // Check cache first
                if let Some(cached_entry) = self.get_from_cache(key.trie_label, key.key) {
                    // Record the read action even for cache hits
                    let trie_root = self.get_trie_root(&memorizer, key.trie_label).await?.unwrap_or(Felt252::ZERO);
                    self.record_read_action(key.trie_label, trie_root, key.key);

                    let result = read::Response {
                        value: cached_entry.value,
                        exist: cached_entry.exists.into(),
                    };
                    retdata_end = result.to_memory(vm, retdata_end)?;
                } else {
                    // Cache miss - fetch from state server
                    let trie_root = self.get_trie_root(&memorizer, key.trie_label).await?.unwrap_or(Felt252::ZERO);
                    let request_payload = ReadRequest {
                        trie_root: pathfinder_crypto::Felt::from(trie_root.to_bytes_be()),
                        key: pathfinder_crypto::Felt::from(key.key.to_bytes_be()),
                    };

                    let client = reqwest::Client::new();
                    let endpoint = format!("{}/read", Self::get_base_url());
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

                            let exists = response.value.is_some();
                            let value = Felt252::from_bytes_be(&response.value.unwrap_or_default().to_be_bytes());

                            // Record the read action
                            self.record_read_action(key.trie_label, trie_root, key.key);

                            // Cache the result
                            self.insert_to_cache(key.trie_label, key.key, exists, value);

                            let result = read::Response {
                                exist: exists.into(),
                                value,
                            };

                            retdata_end = result.to_memory(vm, retdata_end)?;
                        }
                        StatusCode::NOT_FOUND => {
                            // Record the read action
                            self.record_read_action(key.trie_label, trie_root, key.key);

                            // Cache the not found result
                            self.insert_to_cache(key.trie_label, key.key, false, Felt252::ZERO);

                            let result = read::Response {
                                exist: false.into(),
                                value: Felt252::ZERO,
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
            CallHandlerId::Write => {
                let key = keys::injected_state::write::CairoKey::from_memory(vm, calldata)?;
                let trie_root = self.get_trie_root(&memorizer, key.trie_label).await?.unwrap_or(Felt252::ZERO);
                let request_payload = WriteRequest {
                    trie_root: pathfinder_crypto::Felt::from(trie_root.to_bytes_be()),
                    key: pathfinder_crypto::Felt::from(key.key.to_bytes_be()),
                    value: pathfinder_crypto::Felt::from(key.value.to_bytes_be()),
                };

                let client = reqwest::Client::new();
                let endpoint = format!("{}/write", Self::get_base_url());
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

                        let new_trie_root = Felt252::from_bytes_be(&response.trie_root.to_be_bytes());
                        let value = Felt252::from_bytes_be(&response.value.to_be_bytes());

                        // Record the write action
                        self.record_write_action(key.trie_label, trie_root, key.key, key.value);

                        // Update local cache
                        self.update_cache_on_write(key.trie_label, key.key, true, value);

                        let result: write::Response = write::Response { trie_root: new_trie_root };

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
