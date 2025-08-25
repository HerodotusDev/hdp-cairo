use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::insert_value_into_ap},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use pathfinder_common::{hash::TruncatedKeccakHash, trie::TrieNode};
use types::proofs::injected_state::StateProofWrite;

use crate::{patricia::tree::generate_preimage, vars};

pub const HINT_TRIE_ROOT_PREV: &str = "memory[ap] = to_felt_or_relocatable(state_proof.trie_root_prev)";

pub fn hint_trie_root_prev(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.trie_root_prev.to_be_bytes()))
}

pub const HINT_TRIE_ROOT_POST: &str = "memory[ap] = to_felt_or_relocatable(state_proof.trie_root_post)";

pub fn hint_trie_root_post(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.trie_root_post.to_be_bytes()))
}

pub const HINT_LEAF_PREV_KEY: &str = "memory[ap] = to_felt_or_relocatable(state_proof.leaf_prev.key)";

pub fn hint_leaf_prev_key(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.leaf_prev.key.to_be_bytes()))
}

pub const HINT_LEAF_PREV_DATA_VALUE: &str = "memory[ap] = to_felt_or_relocatable(state_proof.leaf_prev.data.value)";

pub fn hint_leaf_prev_data_value(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.leaf_prev.data.value.to_be_bytes()))
}

pub const HINT_LEAF_POST_DATA_VALUE: &str = "memory[ap] = to_felt_or_relocatable(state_proof.leaf_post.data.value)";

pub fn hint_leaf_post_data_value(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.leaf_post.data.value.to_be_bytes()))
}

pub const HINT_PREIMAGE: &str =
    "preimage = {\n    *generate_preimage(state_proof.state_proof_prev)\n    *generate_preimage(state_proof.state_proof_post)\n}";

pub fn hint_preimage(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    let preimage_prev = generate_preimage::<TruncatedKeccakHash>(state_proof.state_proof_prev.into_iter().map(TrieNode::from).collect());
    let preimage_post = generate_preimage::<TruncatedKeccakHash>(state_proof.state_proof_post.into_iter().map(TrieNode::from).collect());

    exec_scopes.insert_value::<HashMap<Felt252, Vec<Felt252>>>(
        vars::scopes::PREIMAGE,
        HashMap::from_iter(preimage_prev.into_iter().chain(preimage_post)),
    );
    Ok(())
}
