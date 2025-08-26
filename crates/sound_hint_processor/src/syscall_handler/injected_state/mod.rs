use std::{cell::RefCell, collections::HashMap, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
};
use serde::{Deserialize, Serialize};
use starknet_crypto::{poseidon_hash_single, poseidon_hash_many};
use strum_macros::FromRepr;
use syscall_handler::{memorizer::Memorizer, traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType, FELT_1
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
        // TODO: implement correctly

        let call_handler_id = CallHandlerId::try_from(request.selector)?;

        let mut calldata = request.calldata_start;
        let memorizer = Memorizer::derive(vm, &mut calldata)?;

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            CallHandlerId::Read => {
                let key = keys::injected_state::read::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_many([&key.trie_label, &key.key])),
                    self.dict_manager.clone(),
                )?;
                let leaf_key = vm.get_integer(ptr)?;
                let result = read::Response {
                    exist: FELT_1,
                    value: *leaf_key,
                };
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Write => {
                let key = keys::injected_state::write::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_single(key.trie_label)),
                    self.dict_manager.clone(),
                )?;
                let _trie_root = vm.get_integer(ptr)?;
            }
            CallHandlerId::Label => {
                let key = keys::injected_state::label::CairoKey::from_memory(vm, calldata)?;
                let ptr = memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_single(key.trie_label)),
                    self.dict_manager.clone(),
                )?;
                let trie_root = vm.get_integer(ptr)?;
                let result = label::Response {
                    trie_root: *trie_root,
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
