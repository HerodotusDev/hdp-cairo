use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_address_from_var_name, get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{
        errors::{hint_errors::HintError, memory_errors::MemoryError},
        vm_core::VirtualMachine,
    },
    Felt252,
};

// PathfinderTrieNode import removed - we now convert directly from TrieNodeSerde
use num_bigint::BigUint;
use types::proofs::state::{StateProof, StateProofWrapper, StateProofs, TrieNodeSerde};
use types::cairo::starknet::storage::CairoTrieNode;
use types::proofs::starknet::storage::TrieNode;


use crate::{
    utils::{count_leading_zero_nibbles_from_hex, split_128},
    vars,
};

pub const HINT_GET_KEY_BE: &str = "ids.key_be = state_proof_wrapper.leaf.key";

pub fn hint_get_key_be(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("Getting key BE");
    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOF_WRAPPER)?;
    let key_be = state_proof_wrapper.leaf.data.value;
    println!("Key BE: {:?}", key_be);
    let key_ptr = get_address_from_var_name(vars::ids::KEY_BE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.insert_value(
        (key_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 0)?,
        Felt252::from_bytes_be(&key_be.as_be_bytes()),
    )?;

    Ok(())
}

pub const HINT_GET_ROOT: &str = "ids.root = state_proof_wrapper.root_hash";

pub fn hint_get_root(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOF_WRAPPER)?;
    let root_hash = state_proof_wrapper.root_hash;
    println!("Root hash: {:?}", root_hash);
    let (root_hash_low, root_hash_high) = split_128(&BigUint::from_bytes_be(root_hash.as_be_bytes()));
    println!("Root hash low: {:?}, Root hash high: {:?}", root_hash_low, root_hash_high);
    let root_ptr = get_address_from_var_name(vars::ids::ROOT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.insert_value(
        (root_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 0)?,
        Felt252::from(root_hash_low),
    )?;
    vm.insert_value(
        (root_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 1)?,
        Felt252::from(root_hash_high),
    )?;
    println!("Root hash inserted into ap");
    Ok(())
}

pub const HINT_GET_KEY_BE_LEADING_ZEROES_NIBBLES: &str =
    "memory[ap] = to_felt_or_relocatable(len(key_be.lstrip(\"0x\")) - len(key_be.lstrip(\"0x\").lstrip(\"0\")))";

pub fn hint_get_key_be_leading_zeroes_nibbles(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("Getting key BE leading zeroes nibbles");

    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOF_WRAPPER)?;
    let key_be = state_proof_wrapper.leaf.data.value;

    let key_be_leading_zeroes_nibbles = count_leading_zero_nibbles_from_hex(&key_be.to_string());
    println!("Key BE leading zeroes nibbles: {:?}", key_be_leading_zeroes_nibbles);
    insert_value_into_ap(vm, Felt252::from(key_be_leading_zeroes_nibbles))?;
    println!("Key BE leading zeroes nibbles inserted into ap");
    Ok(())
}

pub const HINT_GET_PROOF_BYTES_LEN: &str = "segments.write_arg(ids.proof_bytes_len, state_proof.inclusion.proof_bytes_len)";

pub fn hint_get_proof_bytes_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("Getting proof bytes len");
    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOF_WRAPPER)?;
    println!("State proof wrapper: {:?}", state_proof_wrapper);
    let nodes: Vec<TrieNodeSerde> = match state_proof_wrapper.state_proof {
        StateProof::Inclusion(inclusion) => inclusion,
        StateProof::NonInclusion(non_inclusion) => non_inclusion,
        StateProof::Update(update) => update.0, // align with nodes used in hint_get_mpt_proof
    };
    let lens: Vec<MaybeRelocatable> = nodes.into_iter().map(|n| n.byte_len().into()).collect();
    println!("Proof bytes lens: {:?}", lens.len());
    let proof_bytes_len_ptr = get_ptr_from_var_name(vars::ids::PROOF_BYTES_LEN, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.load_data(proof_bytes_len_ptr, &lens)?;
    Ok(())
}

pub const HINT_INCLUSION_PROOF_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(state_proof))";

pub fn hint_inclusion_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("Getting inclusion proof len");
    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOF_WRAPPER)?;
    println!("State proof wrapper: {:?}", state_proof_wrapper);
    let state_proof_len = match state_proof_wrapper.state_proof {
        StateProof::Inclusion(inclusion) => inclusion.len(),
        StateProof::NonInclusion(non_inclusion) => non_inclusion.len(),
        StateProof::Update(update) => update.0.len() + update.1.len(),
    };
    println!("State proof len: {:?}", state_proof_len);
    insert_value_into_ap(vm, Felt252::from(state_proof_len))
}

pub const HINT_GET_MPT_PROOF: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in state_proof.inclusion])";

pub fn hint_get_mpt_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOFS)?;
    let proof = match state_proof_wrapper.state_proof {
        StateProof::Inclusion(inclusion) => inclusion,
        StateProof::NonInclusion(non_inclusion) => non_inclusion,
        StateProof::Update(update) => update.0,
    };

    let mpt_proof_ptr = get_ptr_from_var_name(vars::ids::MPT_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    println!("Proof: {:?}", proof);
    // Convert each TrieNodeSerde into its byte representation and then into
    // 8-byte little-endian chunks loaded into Cairo memory.
    let proof_le_chunks: Result<Vec<MaybeRelocatable>, MemoryError> = proof
        .into_iter()
        .map(|node| {
            // Serialize node to bytes
            let mut node_bytes: Vec<u8> = Vec::new();
            match node {
                TrieNodeSerde::Binary { left, right } => {
                    node_bytes.extend_from_slice(&left.to_be_bytes());
                    node_bytes.extend_from_slice(&right.to_be_bytes());
                }
                TrieNodeSerde::Edge { child, path, .. } => {
                    node_bytes.extend_from_slice(&child.to_be_bytes());
                    node_bytes.extend_from_slice(&path);
                }
            }

            // Chunk into 8-byte little-endian words (represented as BE when constructing the felt)
            let node_le_chunks: Vec<MaybeRelocatable> = node_bytes
                .chunks(8)
                .map(|chunk| {
                    let mut reversed = chunk.to_vec();
                    reversed.reverse();
                    MaybeRelocatable::from(Felt252::from_bytes_be_slice(&reversed))
                })
                .collect();

            // Allocate a segment per node and load the chunks
            let segment = vm.add_memory_segment();
            vm.load_data(segment, &node_le_chunks).map(|_| MaybeRelocatable::from(segment))
        })
        .collect();

    vm.load_data(mpt_proof_ptr, &proof_le_chunks?)?;

    Ok(())
}

pub const HINT_GET_TRIE_NODE_PROOF: &str = "segments.write_arg(ids.nodes_ptr, state_proofs)";

pub fn hint_get_trie_node_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {    
    println!("Getting trie node proof");
    let state_proofs = exec_scopes.get::<StateProofs>(vars::scopes::STATE_PROOFS)?;
    println!("State proofs in Hint Get Node Trie Proof: {:?}", state_proofs);
    let state_proof_wrapper = state_proofs.iter().map(|w| w.clone()).collect::<Vec<StateProofWrapper>>();
    println!("State proof wrapper 2: {:?}", state_proof_wrapper);
    let total_paths: usize = state_proof_wrapper.iter()
    .map(|w| if matches!(w.state_proof, StateProof::Update(_)) { 2 } else { 1 })
    .sum();

    let mut trie_node_proof: Vec<Vec<TrieNode>> = Vec::with_capacity(total_paths);
    
    //todo()! -> futurely unify the structs
    
    for w in state_proof_wrapper {
        match w.state_proof {
            StateProof::Inclusion(v) | StateProof::NonInclusion(v) => {
                trie_node_proof.push(
                    v.into_iter()
                        .map(|node_serde| node_serde.into())
                        .collect()
                );
            }
            StateProof::Update((pre, post)) => {
                trie_node_proof.push(
                    pre.into_iter()
                        .map(|node_serde| node_serde.into())
                        .collect()
                );
                trie_node_proof.push(
                    post.into_iter()
                        .map(|node_serde| node_serde.into())
                        .collect()
                );
            }
        }
    }
    let trie_node_proof_ptr = get_ptr_from_var_name(vars::ids::TRIE_NODE_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let data = trie_node_proof
    .into_iter()
    .map(|nodes| {
        let segment = vm.add_memory_segment();
        let cairo_nodes: Vec<MaybeRelocatable> = nodes
            .into_iter()
            .flat_map(|node| {
                CairoTrieNode(node)
                    .into_iter()
                    .map(MaybeRelocatable::from)
            })
            .collect();
        vm.load_data(segment, &cairo_nodes).unwrap();
        segment
    })
    .map(MaybeRelocatable::from)
    .collect::<Vec<MaybeRelocatable>>();

    vm.load_data(trie_node_proof_ptr, &data)?;

    Ok(())
}
