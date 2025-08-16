use std::{collections::HashMap, sync::Arc};

use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
};
use pathfinder_crypto::Felt;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use syscall_handler::{traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    actions::action::{Action, ActionTracker, ActionType, CallHandlerId},
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        structs::CairoFelt,
        traits::CairoType,
    },
    Felt252,
};

fn default_client() -> Arc<Client> {
    Arc::new(Client::new())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallContractHandler {
    #[serde(skip, default = "default_client")]
    client: Arc<Client>,
    base_url: String,
    pub trie_ids: Vec<Felt>,
    pub actions: Vec<Action>,
    #[serde(skip)]
    local_storage: HashMap<String, Felt>,
}

impl ActionTracker for CallContractHandler {
    fn record_action(&mut self, action: Action) {
        self.actions.push(action);
    }

    fn get_actions(&self) -> &Vec<Action> {
        &self.actions
    }

    fn clear_actions(&mut self) {
        self.actions.clear();
    }
}

impl Default for CallContractHandler {
    fn default() -> Self {
        let base_url = std::env::var("INJECTED_STATE_BASE_URL").unwrap_or("http://localhost:3000".to_string());
        Self::new(&base_url).expect("Failed to create handler")
    }
}

impl CallContractHandler {
    pub fn new(base_url: &str) -> Result<Self, anyhow::Error> {
        let client = Client::new();

        Ok(Self {
            client: Arc::new(client),
            base_url: base_url.to_string(),
            trie_ids: vec![],
            local_storage: HashMap::new(),
            actions: vec![],
        })
    }

    async fn ensure_trie_exists(&mut self) -> Result<(), anyhow::Error> {
        if self.trie_ids.is_empty() {
            return Err(anyhow::anyhow!("No tree root hash has been set in module"));
        }

        let current_trie_id = &self.trie_ids[self.trie_ids.len() - 1];

        // Calling new-trie will either load the trie from the database or create a new one
        let create_url = format!("{}/new-trie", self.base_url);
        let request_body = serde_json::json!({
            "id": current_trie_id
        });

        let response = self.client.post(&create_url).json(&request_body).send().await?;

        if response.status().is_success() {
            Ok(())
        } else {
            Err(anyhow::anyhow!("Failed to create trie: {}", response.status()))
        }
    }

    fn upsert_key_locally(&mut self, key: Felt, value: Felt) {
        // Update local storage with prefixed key
        let prefixed_key = self.create_prefixed_key(key);
        self.local_storage.insert(prefixed_key, value);

        // Record the upsert action
        let root_hash = self.get_current_tree_id();
        self.record_action(Action::new(*root_hash, ActionType::Write, key, Some(value)));
    }

    async fn get_key(&mut self, key: Felt) -> Result<Option<Felt>, anyhow::Error> {
        // First check local storage with prefixed key
        let prefixed_key = self.create_prefixed_key(key);
        if let Some(value) = self.local_storage.get(&prefixed_key) {
            // Record the read action
            let root_hash = self.get_current_tree_id();
            let value_clone = value.clone();
            self.record_action(Action::new(*root_hash, ActionType::Read, key, Some(value_clone)));
            return Ok(Some(value_clone));
        }

        // If not found locally, fetch from external API and store locally
        self.ensure_trie_exists().await?;

        let url = format!("{}/get-key/{}", self.base_url, self.trie_ids[self.trie_ids.len() - 1]);
        let response = self.client.get(&url).query(&[("key", key)]).send().await?;

        if response.status().is_success() {
            let proof_response: serde_json::Value = response.json().await?;
            if let Some(value) = proof_response["value"].as_str() {
                let value_felt = Felt::from_hex_str(value).unwrap_or(Felt::ZERO);
                // Store in local cache with prefixed key
                self.local_storage.insert(prefixed_key, value_felt);

                // Record the read action
                let root_hash = self.get_current_tree_id();
                self.record_action(Action::new(*root_hash, ActionType::Read, key, Some(value_felt)));

                Ok(Some(value_felt))
            } else {
                // Record the read action with no value found
                let root_hash = self.get_current_tree_id();
                self.record_action(Action::new(*root_hash, ActionType::Read, key, None));
                Ok(None)
            }
        } else {
            // Record the read action with error (no value)
            let root_hash = self.get_current_tree_id();
            self.record_action(Action::new(*root_hash, ActionType::Read, key, None));
            Err(anyhow::anyhow!("Failed to get key: {}", response.status()))
        }
    }

    fn key_exists(&mut self, key: Felt) -> bool {
        let prefixed_key = self.create_prefixed_key(key);
        let exists = self.local_storage.contains_key(&prefixed_key);

        // Record the existence check action
        let root_hash = self.get_current_tree_id();
        let exists_felt = if exists { Felt::ONE } else { Felt::ZERO };
        self.record_action(Action::new(*root_hash, ActionType::Read, key, Some(exists_felt)));

        exists
    }

    async fn set_tree_root(&mut self, tree_root: Felt) -> Result<(), anyhow::Error> {
        self.trie_ids.push(tree_root);

        self.ensure_trie_exists().await?;
        Ok(())
    }

    /// Get the current tree id
    fn get_current_tree_id(&self) -> &Felt {
        self.trie_ids.last().expect("No tree root hash has been set in module")
    }

    /// Create a prefixed key for local storage using current tree id
    fn create_prefixed_key(&self, key: Felt) -> String {
        format!("{}:{}", self.get_current_tree_id(), key)
    }
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let call_handler_id = CallHandlerIdWrapper::try_from(request.selector)?;

        match call_handler_id.0 {
            CallHandlerId::ReadKey => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                if fields.len() < 3 {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::ZERO,
                        info: "ReadKey requires at least key".to_string(),
                    });
                }

                let value = fields[2].to_bytes_be().into();
                // Get value from local storage first, then from state server API if not found
                let (value, exists) = match self.get_key(value).await {
                    Ok(Some(val)) => (Felt252::from_bytes_be(&val.to_be_bytes()), Felt252::ONE),
                    Ok(None) => (Felt252::ZERO, Felt252::ZERO),
                    Err(e) => {
                        panic!("Error retrieving key: {}", e);
                    }
                };

                let output = ReadKeyResponseTypeOutput { value, exists };

                let retdata_start = vm.add_memory_segment();
                let retdata_end = output.to_memory(vm, retdata_start)?;

                Ok(Self::Response {
                    retdata_start,
                    retdata_end,
                })
            }
            CallHandlerId::UpsertKey => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                if fields.len() < 4 {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::ZERO,
                        info: "UpsertKey requires at least key and value".to_string(),
                    });
                }
                let key = fields[2].to_bytes_be().into();
                let value = fields[3].to_bytes_be().into();

                // Insert/update in local storage
                self.upsert_key_locally(key, value);

                let output = UpsertKeyResponseTypeOutput { success: Felt252::ONE };

                let retdata_start = vm.add_memory_segment();
                let retdata_end = output.to_memory(vm, retdata_start)?;

                Ok(Self::Response {
                    retdata_start,
                    retdata_end,
                })
            }
            CallHandlerId::DoesKeyExist => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                if fields.len() < 3 {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::ZERO,
                        info: "DoesKeyExist requires at least key".to_string(),
                    });
                }

                let key = fields[2].to_bytes_be().into();

                // Check if key exists in local storage
                let exists = if self.key_exists(key) { Felt252::ONE } else { Felt252::ZERO };

                let output = DoesKeyExistResponseTypeOutput { exists };

                let retdata_start = vm.add_memory_segment();
                let retdata_end = output.to_memory(vm, retdata_start)?;

                Ok(Self::Response {
                    retdata_start,
                    retdata_end,
                })
            }
            CallHandlerId::SetTreeRoot => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                if fields.len() < 3 {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::ZERO,
                        info: "SetTreeRoot requires at least tree_root".to_string(),
                    });
                }

                let tree_root = fields[2].to_bytes_be().into();
                // Set the tree id via state server API
                if let Err(e) = self.set_tree_root(tree_root).await {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::ZERO,
                        info: format!("Failed to set tree id: {}", e),
                    });
                }

                let output = SetTreeIdResponseTypeOutput { success: Felt252::ONE };

                let retdata_start = vm.add_memory_segment();
                let retdata_end = output.to_memory(vm, retdata_start)?;

                Ok(Self::Response {
                    retdata_start,
                    retdata_end,
                })
            }
        }
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        Ok(())
    }
}

#[derive(Default, Debug, Clone)]
pub struct ReadKeyResponseTypeOutput {
    pub value: Felt252,
    pub exists: Felt252,
}

#[derive(Default, Debug, Clone)]
pub struct UpsertKeyResponseTypeOutput {
    pub success: Felt252,
}

#[derive(Default, Debug, Clone)]
pub struct DoesKeyExistResponseTypeOutput {
    pub exists: Felt252,
}

#[derive(Default, Debug, Clone)]
pub struct SetTreeIdResponseTypeOutput {
    pub success: Felt252,
}

impl CairoType for UpsertKeyResponseTypeOutput {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let success = *CairoFelt::from_memory(vm, address)?;
        Ok(Self { success })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, mut address: Relocatable) -> Result<Relocatable, MemoryError> {
        address = CairoFelt::from(self.success).to_memory(vm, address)?;
        Ok(address)
    }

    fn n_fields(vm: &VirtualMachine, address: Relocatable) -> Result<usize, MemoryError> {
        let n = CairoFelt::n_fields(vm, address)?;
        Ok(n)
    }
}

impl CairoType for ReadKeyResponseTypeOutput {
    fn from_memory(vm: &VirtualMachine, mut address: Relocatable) -> Result<Self, MemoryError> {
        let value = *CairoFelt::from_memory(vm, address)?;
        address += CairoFelt::n_fields(vm, address)?;
        let exists = *CairoFelt::from_memory(vm, address)?;
        Ok(Self { value, exists })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, mut address: Relocatable) -> Result<Relocatable, MemoryError> {
        address = CairoFelt::from(self.value).to_memory(vm, address)?;
        address = CairoFelt::from(self.exists).to_memory(vm, address)?;
        Ok(address)
    }

    fn n_fields(vm: &VirtualMachine, mut address: Relocatable) -> Result<usize, MemoryError> {
        let mut n = CairoFelt::n_fields(vm, address)?;
        address = (address + CairoFelt::n_fields(vm, address)?)?;
        n += CairoFelt::n_fields(vm, address)?;
        Ok(n)
    }
}

impl CairoType for DoesKeyExistResponseTypeOutput {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let exists = *CairoFelt::from_memory(vm, address)?;
        Ok(Self { exists })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        CairoFelt::from(self.exists).to_memory(vm, address)
    }

    fn n_fields(vm: &VirtualMachine, address: Relocatable) -> Result<usize, MemoryError> {
        CairoFelt::n_fields(vm, address)
    }
}

impl CairoType for SetTreeIdResponseTypeOutput {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let success = *CairoFelt::from_memory(vm, address)?;
        Ok(Self { success })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        CairoFelt::from(self.success).to_memory(vm, address)
    }

    fn n_fields(vm: &VirtualMachine, address: Relocatable) -> Result<usize, MemoryError> {
        CairoFelt::n_fields(vm, address)
    }
}

pub struct CallHandlerIdWrapper(CallHandlerId);

impl TryFrom<Felt252> for CallHandlerIdWrapper {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        let id = CallHandlerId::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })?;
        Ok(Self(id))
    }
}
