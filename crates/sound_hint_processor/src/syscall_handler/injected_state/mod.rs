use std::sync::Arc;

use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{
    call_contract::debug::decode_byte_array_felts, traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult,
};
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
    GetTrieRootHash = 3,
}

#[derive(Debug, Clone, Copy)]
pub enum ActionType {
    Read = 0,
    Write = 1,
}

impl ActionType {
    fn as_u8(self) -> u8 {
        self as u8
    }
}

#[derive(Debug, Clone)]
pub struct Action {
    pub root_hash: String,
    pub action_type: ActionType,
    pub key: String,
    pub value: Option<String>,
}

impl Action {
    pub fn new(root_hash: String, action_type: ActionType, key: String, value: Option<String>) -> Self {
        Self {
            root_hash,
            action_type,
            key,
            value,
        }
    }

    /// Serialize action to string format: "root_hash;action_type;key[;value]"
    pub fn serialize(&self) -> String {
        match self.action_type {
            ActionType::Read => format!("{};{};{}", self.root_hash, self.action_type.as_u8(), self.key),
            ActionType::Write => match &self.value {
                Some(val) => format!("{};{};{};{}", self.root_hash, self.action_type.as_u8(), self.key, val),
                None => format!("{};{};{}", self.root_hash, self.action_type.as_u8(), self.key),
            },
        }
    }

    /// Deserialize action from string format: "root_hash;action_type;key[;value]"
    pub fn deserialize(action_str: &str) -> Result<Self, anyhow::Error> {
        let parts: Vec<&str> = action_str.split(';').collect();

        if parts.len() < 3 {
            return Err(anyhow::anyhow!(
                "Invalid action format: expected at least 3 parts, got {}",
                parts.len()
            ));
        }

        let root_hash = parts[0].to_string();
        let action_type = match parts[1].parse::<u8>()? {
            0 => ActionType::Read,
            1 => ActionType::Write,
            _ => return Err(anyhow::anyhow!("Invalid action type: {}", parts[1])),
        };
        let key = parts[2].to_string();
        let value = if parts.len() > 3 && !parts[3].is_empty() {
            Some(parts[3].to_string())
        } else {
            None
        };

        Ok(Self::new(root_hash, action_type, key, value))
    }
}

/// Trait for tracking actions in the injected state system
pub trait ActionTracker {
    /// Record an action with its type, root hash, key, and optional value
    fn record_action(&mut self, action_type: ActionType, root_hash: &str, key: &str, value: Option<&str>);

    /// Record an action using the Action type
    fn record_action_typed(&mut self, action: Action);

    /// Get all recorded actions as strings
    fn get_actions(&self) -> &Vec<String>;

    /// Get all recorded actions as Action objects
    fn get_actions_typed(&self) -> Result<Vec<Action>, anyhow::Error>;

    /// Clear all recorded actions
    fn clear_actions(&mut self);
}

fn default_client() -> Arc<Client> {
    Arc::new(Client::new())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallContractHandler {
    #[serde(skip, default = "default_client")]
    client: Arc<Client>,
    base_url: String,
    trie_id: String,
    pub actions: Vec<String>,
}

impl ActionTracker for CallContractHandler {
    fn record_action(&mut self, action_type: ActionType, root_hash: &str, key: &str, value: Option<&str>) {
        let action = Action::new(root_hash.to_string(), action_type, key.to_string(), value.map(|v| v.to_string()));
        self.record_action_typed(action);
    }

    fn record_action_typed(&mut self, action: Action) {
        let action_str = action.serialize();
        self.actions.push(action_str);
    }

    fn get_actions(&self) -> &Vec<String> {
        &self.actions
    }

    fn get_actions_typed(&self) -> Result<Vec<Action>, anyhow::Error> {
        self.actions.iter().map(|action_str| Action::deserialize(action_str)).collect()
    }

    fn clear_actions(&mut self) {
        self.actions.clear();
    }
}

impl Default for CallContractHandler {
    fn default() -> Self {
        Self::new("http://localhost:3000", "injected_state_trie_sound").expect("Failed to create handler")
    }
}

impl CallContractHandler {
    pub fn new(base_url: &str, trie_id: &str) -> Result<Self, anyhow::Error> {
        let client = Client::new();
        Ok(Self {
            client: Arc::new(client),
            base_url: base_url.to_string(),
            trie_id: trie_id.to_string(),
            actions: vec![],
        })
    }

    async fn ensure_trie_exists(&self) -> Result<(), anyhow::Error> {
        let url = format!("{}/new-trie", self.base_url);
        let request_body = serde_json::json!({
            "id": self.trie_id
        });

        let response = self.client.post(&url).json(&request_body).send().await?;

        if response.status().is_success() || response.status().as_u16() == 409 {
            // 409 Conflict means trie already exists, which is fine
            Ok(())
        } else {
            Err(anyhow::anyhow!("Failed to create trie: {}", response.status()))
        }
    }

    async fn upsert_key(&mut self, key: &str, value: &str) -> Result<(), anyhow::Error> {
        self.ensure_trie_exists().await?;

        let url = format!("{}/update-trie/{}", self.base_url, self.trie_id);
        let request_body = serde_json::json!({
            "key": key,
            "value": value
        });

        let response = self.client.post(&url).json(&request_body).send().await?;

        if response.status().is_success() {
            // Record the upsert action
            let trie_id = self.trie_id.clone();
            self.record_action(ActionType::Write, &trie_id, key, Some(value));
            Ok(())
        } else {
            Err(anyhow::anyhow!("Failed to upsert key: {}", response.status()))
        }
    }

    async fn get_key(&mut self, key: &str) -> Result<Option<String>, anyhow::Error> {
        self.ensure_trie_exists().await?;

        let url = format!("{}/get-key/{}", self.base_url, self.trie_id);
        let response = self.client.get(&url).query(&[("key", key)]).send().await?;

        if response.status().is_success() {
            let proof_response: serde_json::Value = response.json().await?;
            if let Some(value) = proof_response["value"].as_str() {
                let value_str = value.to_string();
                // Record the read action
                let trie_id = self.trie_id.clone();
                self.record_action(ActionType::Read, &trie_id, key, Some(&value_str));
                Ok(Some(value_str))
            } else {
                // Record the read action with no value found
                let trie_id = self.trie_id.clone();
                self.record_action(ActionType::Read, &trie_id, key, None);
                Ok(None)
            }
        } else {
            // Record the read action with error (no value)
            let trie_id = self.trie_id.clone();
            self.record_action(ActionType::Read, &trie_id, key, None);
            Err(anyhow::anyhow!("Failed to get key: {}", response.status()))
        }
    }

    async fn does_key_exist(&mut self, key: &str) -> Result<bool, anyhow::Error> {
        self.ensure_trie_exists().await?;

        let url = format!("{}/get-key/{}", self.base_url, self.trie_id);
        let response = self.client.get(&url).query(&[("key", key)]).send().await?;

        if response.status().is_success() {
            let proof_response: serde_json::Value = response.json().await?;
            let exists = proof_response["exists"].as_bool().unwrap_or(false);

            // Record the existence check action
            let exists_str = if exists { "1" } else { "0" };
            let trie_id = self.trie_id.clone();
            self.record_action(ActionType::Read, &trie_id, key, Some(&exists_str));

            Ok(exists)
        } else {
            // Record the existence check action with error
            let trie_id = self.trie_id.clone();
            self.record_action(ActionType::Read, &trie_id, key, Some("0"));
            Err(anyhow::anyhow!("Failed to check key existence: {}", response.status()))
        }
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
        println!("EXECUTE SYSCALL HANDLER FOR INJECTED STATE SOUND RUN");
        let call_handler_id = CallHandlerId::try_from(request.selector)?;
        println!("call_handler_id: {:?}", call_handler_id);

        match call_handler_id {
            CallHandlerId::ReadKey => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                let key = decode_byte_array_felts(fields);
                println!("Reading key: {}", key);

                // Get value from state server API
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
                println!("UPSERT");
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                // For upsert, we expect key and value to be provided in calldata
                // We'll assume the first half is the key and second half is the value
                if fields.len() < 2 {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::from(fields.len()),
                        info: "UpsertKey requires at least key and value".to_string(),
                    });
                }

                let mid = fields.len() / 2;
                let key_fields = &fields[..mid];
                let value_fields = &fields[mid..];

                let key = decode_byte_array_felts(key_fields.to_vec());
                let value = decode_byte_array_felts(value_fields.to_vec());

                println!("Upserting key: {}, value: {}", key, value);

                // Insert/update via state server API
                if let Err(e) = self.upsert_key(&key, &value).await {
                    return Err(SyscallExecutionError::InvalidSyscallInput {
                        input: Felt252::ZERO,
                        info: format!("Failed to upsert key: {}", e),
                    });
                }

                Ok(Self::Response {
                    retdata_start: request.calldata_end,
                    retdata_end: request.calldata_end,
                })
            }
            CallHandlerId::DoesKeyExist => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();

                let key = decode_byte_array_felts(fields);
                println!("Checking if key exists: {}", key);

                // Check if key exists via state server API
                let exists = match self.does_key_exist(&key).await {
                    Ok(exists) => {
                        if exists {
                            Felt252::ONE
                        } else {
                            Felt252::ZERO
                        }
                    }
                    Err(e) => {
                        println!("Error checking key existence: {}", e);
                        Felt252::ZERO
                    }
                };

                let output = DoesKeyExistResponseTypeOutput { exists };

                let retdata_start = vm.add_memory_segment();
                let retdata_end = output.to_memory(vm, retdata_start)?;

                Ok(Self::Response {
                    retdata_start,
                    retdata_end,
                })
            }
            CallHandlerId::GetTrieRootHash => {
                let output = GetTrieRootHashResponseTypeOutput {
                    root_hash: self.trie_id.clone(),
                };
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
pub struct DoesKeyExistResponseTypeOutput {
    pub exists: Felt252,
}

#[derive(Default, Debug, Clone)]
pub struct GetTrieRootHashResponseTypeOutput {
    pub root_hash: String,
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

impl CairoType for GetTrieRootHashResponseTypeOutput {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let root_hash = Felt252::ZERO.to_string();
        Ok(Self { root_hash })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        let root_hash = Felt252::ZERO;
        CairoFelt::from(root_hash).to_memory(vm, address)
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
