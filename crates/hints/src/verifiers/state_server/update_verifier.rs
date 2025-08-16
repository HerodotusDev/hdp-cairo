use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{insert_value_into_ap, get_ptr_from_var_name, get_integer_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine, errors::memory_errors::MemoryError},
    Felt252, types::relocatable::MaybeRelocatable,
};
use types::proofs::{mpt::MPTProof, state::{TrieNodeSerde, StateProofWrapper, StateProof}};

use crate::{vars, utils::{count_leading_zero_nibbles_from_hex}};

pub const HINT_GET_UPDATE_PROOF_AT: &str = "ids.update = state_proof_wrapper.state_proof.update";

pub fn hint_get_update_proof_at(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof_wrapper = exec_scopes.get::<StateProofWrapper>(vars::scopes::STATE_PROOF_WRAPPER)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    Ok(())
}