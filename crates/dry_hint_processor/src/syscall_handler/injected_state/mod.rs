use std::{collections::HashMap, sync::Arc};

use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use chrono::Utc;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::cairo::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    structs::CairoFelt,
    traits::CairoType,
};

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    ReadKey = 0,
    UpsertKey = 1,
    DoesKeyExist = 2,
    SetTreeRoot = 3,
}

fn default_client() -> Arc<Client> {
    Arc::new(Client::new())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallContractHandler {
    #[serde(skip, default = "default_client")]
    client: Arc<Client>,
    base_url: String,
    pub trie_ids: Vec<String>,
    pub upsert_actions: Vec<String>,
    #[serde(skip)]
    local_storage: HashMap<String, String>,
    #[serde(skip)]
    key_to_action_index: HashMap<String, usize>,
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
            upsert_actions: vec![],
            key_to_action_index: HashMap::new(),
        })
    }

    async fn ensure_trie_exists(&mut self) -> Result<(), anyhow::Error> {
        if self.trie_ids.is_empty() {
            let new_trie_id = format!("injected_state_trie_dry_{}", Utc::now().timestamp_millis());
            self.trie_ids.push(new_trie_id);
        }

        let current_trie_id = &self.trie_ids[self.trie_ids.len() - 1];

        // First check if the trie already exists
        let check_url = format!("{}/check-trie/{}", self.base_url, current_trie_id);
        let check_response = self.client.get(&check_url).send().await?;

        if check_response.status().is_success() {
            let check_result: serde_json::Value = check_response.json().await?;
            if let Some(exists) = check_result["exists"].as_bool() {
                if exists {
                    // Trie already exists, no need to create
                    return Ok(());
                }
            }
        }

        // Trie doesn't exist, create it
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

    fn upsert_key_locally(&mut self, key: &str, value: &str) {
        // Update local storage with prefixed key
        let prefixed_key = self.create_prefixed_key(key);
        self.local_storage.insert(prefixed_key, value.to_string());

        // Get current root hash (use current trie ID)
        let root_hash = self.get_current_tree_id();

        // Format the action as "rootHash;key;value" (use original key, not prefixed)
        let action = format!("{};{};{}", root_hash, key, value);

        // Create a unique key for the action index (includes tree id to handle same key in different trees)
        let action_key = format!("{}:{}", root_hash, key);

        // Check if we already have an action for this key in this tree
        if let Some(&index) = self.key_to_action_index.get(&action_key) {
            // Update existing action (optimization: keep only latest value)
            self.upsert_actions[index] = action;
        } else {
            // Add new action
            let index = self.upsert_actions.len();
            self.upsert_actions.push(action);
            self.key_to_action_index.insert(action_key, index);
        }
    }

    async fn get_key(&mut self, key: &str) -> Result<Option<String>, anyhow::Error> {
        // First check local storage with prefixed key
        let prefixed_key = self.create_prefixed_key(key);
        if let Some(value) = self.local_storage.get(&prefixed_key) {
            return Ok(Some(value.clone()));
        }

        // If not found locally, fetch from external API and store locally
        self.ensure_trie_exists().await?;

        let url = format!("{}/get-proof/{}", self.base_url, self.trie_ids[self.trie_ids.len() - 1]);
        let response = self.client.get(&url).query(&[("key", key)]).send().await?;

        if response.status().is_success() {
            let proof_response: serde_json::Value = response.json().await?;
            if let Some(value) = proof_response["value"].as_str() {
                let value_str = value.to_string();
                // Store in local cache with prefixed key
                self.local_storage.insert(prefixed_key, value_str.clone());
                Ok(Some(value_str))
            } else {
                Ok(None)
            }
        } else {
            Err(anyhow::anyhow!("Failed to get key: {}", response.status()))
        }
    }

    fn key_exists(&self, key: &str) -> bool {
        let prefixed_key = self.create_prefixed_key(key);
        self.local_storage.contains_key(&prefixed_key)
    }

    async fn set_tree_root(&mut self, tree_root: &str) -> Result<(), anyhow::Error> {
        self.trie_ids.push(tree_root.to_string());
        self.ensure_trie_exists().await?;
        Ok(())
    }

    /// Get the current tree id (or default if none exists)
    fn get_current_tree_id(&self) -> &str {
        self.trie_ids.last().map(|id| id.as_str()).unwrap_or("default")
    }

    /// Create a prefixed key for local storage using current tree id
    fn create_prefixed_key(&self, key: &str) -> String {
        format!("{}:{}", self.get_current_tree_id(), key)
    }

    /// Get all upsert actions for dumping to dry_run_output.json
    pub fn get_upsert_actions(&self) -> &Vec<String> {
        &self.upsert_actions
    }

    /// Clear all upsert actions (useful for testing or resetting state)
    pub fn clear_upsert_actions(&mut self) {
        self.upsert_actions.clear();
        self.key_to_action_index.clear();
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
        let call_handler_id = CallHandlerId::try_from(request.selector)?;

        match call_handler_id {
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
                let key = fields[2].to_string();

                // Get value from local storage first, then from state server API if not found
                let (value, exists) = match self.get_key(&key).await {
                    Ok(Some(val)) => {
                        // Try to parse the value as a hex string and convert to Felt252
                        let value_felt = if val.starts_with("0x") {
                            Felt252::from_hex(&val).unwrap_or(Felt252::ZERO)
                        } else {
                            val.parse::<u64>().map(Felt252::from).unwrap_or(Felt252::ZERO)
                        };
                        (value_felt, Felt252::ONE)
                    }
                    Ok(None) => (Felt252::ZERO, Felt252::ZERO),
                    Err(e) => {
                        println!("Error getting key: {}", e);
                        (Felt252::ZERO, Felt252::ZERO)
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
                let key = fields[2].to_string();
                let value = fields[3].to_string();

                // Insert/update in local storage
                self.upsert_key_locally(&key, &value);

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

                let key = fields[2].to_string();

                // Check if key exists in local storage
                let exists = if self.key_exists(&key) { Felt252::ONE } else { Felt252::ZERO };

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

                let tree_root = fields[2].to_string();
                // Set the tree id via state server API
                if let Err(e) = self.set_tree_root(&tree_root).await {
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
