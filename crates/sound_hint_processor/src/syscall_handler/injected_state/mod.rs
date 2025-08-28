use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
};
use serde::{Deserialize, Serialize};
use starknet_crypto::poseidon_hash_many;
use strum_macros::FromRepr;
use syscall_handler::{memorizer::Memorizer, traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::{
        injected_state::{label, read, write, INCLUSION, LABEL_RUNTIME, NON_INCLUSION, WRITE},
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
        FELT_0, FELT_1,
    },
    keys, Felt252,
};

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    Label = 0,
    Read = 1,
    Write = 2,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CallContractHandler {
    #[serde(skip)]
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl CallContractHandler {
    pub fn new(dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { dict_manager }
    }

    fn get_trie_root(&self, memorizer: &Memorizer, label: Felt252) -> Result<Option<Felt252>, HintError> {
        let key = MaybeRelocatable::Int(poseidon_hash_many(&[LABEL_RUNTIME, label]));
        match memorizer.read_key_int(&key, self.dict_manager.clone()) {
            Ok(trie_root) if trie_root == Memorizer::DEFAULT_VALUE => Ok(None),
            Ok(trie_root) => Ok(Some(trie_root)),
            Err(ref e) if matches!(e, HintError::NoValueForKey(_)) => Ok(None),
            Err(e) => Err(e),
        }
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
            CallHandlerId::Label => {
                let key = keys::injected_state::label::CairoKey::from_memory(vm, calldata)?;

                let trie_root = self.get_trie_root(&memorizer, key.trie_label)?;

                let result = label::Response {
                    trie_root: trie_root.unwrap_or(Felt252::ZERO),
                    exists: trie_root.is_some().into(),
                };

                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Read => {
                let key = keys::injected_state::read::CairoKey::from_memory(vm, calldata)?;

                let trie_root = self
                    .get_trie_root(&memorizer, key.trie_label)?
                    .ok_or(HintError::NoValueForKey(Box::new(key.trie_label.into())))?;

                let maybe_ptr = memorizer
                    .read_key(
                        &MaybeRelocatable::Int(poseidon_hash_many([&INCLUSION, &trie_root, &key.key])),
                        self.dict_manager.clone(),
                    )
                    .map(Some)
                    .or_else(|err| {
                        if matches!(err, HintError::NoValueForKey(_)) {
                            memorizer
                                .read_key(
                                    &MaybeRelocatable::Int(poseidon_hash_many([&NON_INCLUSION, &trie_root, &key.key])),
                                    self.dict_manager.clone(),
                                )
                                .map(|_| None)
                        } else {
                            Err(err)
                        }
                    })?;

                let result = match maybe_ptr {
                    Some(ptr) => {
                        let leaf_key = vm.get_integer(ptr)?;
                        read::Response {
                            exist: FELT_1,
                            value: *leaf_key,
                        }
                    }
                    None => read::Response {
                        exist: FELT_0,
                        value: FELT_0,
                    },
                };

                retdata_end = result.to_memory(vm, retdata_end)?;
            }
            CallHandlerId::Write => {
                let key = keys::injected_state::write::CairoKey::from_memory(vm, calldata)?;

                let trie_root = self
                    .get_trie_root(&memorizer, key.trie_label)?
                    .ok_or(HintError::NoValueForKey(Box::new(key.trie_label.into())))?;

                let new_root = *vm.get_integer(memorizer.read_key(
                    &MaybeRelocatable::Int(poseidon_hash_many([&WRITE, &trie_root, &key.key])),
                    self.dict_manager.clone(),
                )?)?;

                memorizer.set_key(
                    &MaybeRelocatable::Int(poseidon_hash_many(&[LABEL_RUNTIME, key.trie_label])),
                    &MaybeRelocatable::Int(new_root),
                    self.dict_manager.clone(),
                )?;

                let result = write::Response { trie_root: new_root };

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
