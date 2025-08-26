use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_address_from_var_name, get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::proofs::injected_state::{CairoTrieNodeSerde, StateProofRead};

use crate::vars;

pub const HINT_GET_KEY_BE: &str = "ids.key_be = state_proof_read.leaf.key";

pub fn hint_get_key_be(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofRead>(vars::scopes::STATE_PROOF)?;
    let key_be = state_proof.leaf.key;
    let key_ptr = get_address_from_var_name(vars::ids::KEY_BE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.insert_value(
        (key_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 0)?,
        Felt252::from_bytes_be(&key_be.to_be_bytes()),
    )?;

    Ok(())
}

pub const HINT_INCLUSION_PROOF_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(state_proof))";

pub fn hint_inclusion_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofRead>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from(state_proof.state_proof.len()))
}

pub const HINT_GET_TRIE_ROOT_HASH: &str = "ids.root_hash = state_proof_read.trie_root";

pub fn hint_get_trie_root_hash(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofRead>(vars::scopes::STATE_PROOF)?;
    let root_hash = state_proof.trie_root;
    println!("root_hash: {:?}", root_hash);
    let root_hash_ptr = get_address_from_var_name(vars::ids::ROOT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    println!("root_hash_ptr: {:?}", root_hash_ptr);

    vm.insert_value(
        (root_hash_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 0)?,
        Felt252::from_bytes_be(&root_hash.to_be_bytes()),
    )?;

    Ok(())
}


pub const HINT_GET_TRIE_NODE_PROOF: &str = "segments.write_arg(ids.nodes_ptr, state_proof)";

pub fn hint_get_trie_node_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofRead>(vars::scopes::STATE_PROOF)?;

    let nodes_ptr = get_ptr_from_var_name(vars::ids::NODES_PTR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let data = state_proof
        .state_proof
        .into_iter()
        .map(|node| {
            let segment = vm.add_memory_segment();
            let data = &CairoTrieNodeSerde(node)
                .into_iter()
                .map(MaybeRelocatable::from)
                .collect::<Vec<MaybeRelocatable>>();
            vm.load_data(segment, data).unwrap();
            segment
        })
        .map(MaybeRelocatable::from)
        .collect::<Vec<MaybeRelocatable>>();

    vm.load_data(nodes_ptr, &data)?;

    Ok(())
}
