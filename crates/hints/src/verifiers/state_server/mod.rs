use std::{any::Any, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_into_ap, get_ptr_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252, types::relocatable::MaybeRelocatable,
};
use types::proofs::state::{StateProof, StateProofs, TrieNodeSerde};

use crate::vars;

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'batch_state_server': state_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proofs = exec_scopes.get::<StateProofs>(vars::scopes::STATE_PROOFS)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let batch: Box<dyn Any> = match state_proofs[idx - 1].clone() {
        StateProof::Inclusion(proofs) => Box::new(proofs),
        // StateProof::NonInclusion(proofs) => Box::new(proofs),
        StateProof::Update(proofs) => Box::new(proofs),
    };
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get_dict_manager()?);

    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::BATCH_STATE_SERVER), batch),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}

// pub const HINT_INCLUSION_PROOF_AT: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in proof.inclusion])";

// pub fn hint_inclusion_proof_at(
//     vm: &mut VirtualMachine,
//     exec_scopes: &mut ExecutionScopes,
//     hint_data: &HintProcessorData,
//     _constants: &HashMap<String, Felt252>,
// ) -> Result<(), HintError> {
//     let inclusion = exec_scopes.get::<Vec<TrieNodeSerde>>(vars::scopes::INCLUSION_PROOF)?;
//     let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
//         .try_into()
//         .unwrap();
//     let proof = inclusion[idx].clone();
// }

pub const HINT_INCLUSION_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(state_proof.inclusion))";

pub fn hint_inclusion_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inclusion = exec_scopes.get::<Vec<TrieNodeSerde>>(vars::scopes::INCLUSION_PROOF)?;

    insert_value_into_ap(vm, Felt252::from(inclusion.len()))
}

pub const HINT_ACCOUNT_PROOF_BYTES_LEN: &str = "segments.write_arg(ids.inclusion_proof_bytes, proof.inclusion_proof_bytes_len)";

pub fn hint_inclusion_proof_bytes_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inclusion = exec_scopes.get::<Vec<TrieNodeSerde>>(vars::scopes::PROOF)?;
    let proof_bytes_len_ptr = get_ptr_from_var_name(vars::ids::INCLUSION_PROOF_BYTES, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let proof_len: Vec<MaybeRelocatable> = inclusion.into_iter().map(|f| f.len().into()).collect();
    vm.load_data(proof_bytes_len_ptr, &proof_len)?;
    Ok(())
}

pub const HINT_GET_MPT_PROOF: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in proof.proof])";

pub fn hint_get_mpt_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;
    let mpt_proof_ptr = get_ptr_from_var_name(vars::ids::MPT_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let proof_le_chunks: Result<Vec<MaybeRelocatable>, MemoryError> = proof
        .proof
        .into_iter()
        .map(|p| {
            p.chunks(8)
                .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
                .collect::<Vec<MaybeRelocatable>>()
        })
        .map(|f| {
            let segment = vm.add_memory_segment();
            vm.load_data(segment, &f).map(|_| MaybeRelocatable::from(segment))
        })
        .collect();

    vm.load_data(mpt_proof_ptr, &proof_le_chunks?)?;

    Ok(())
}