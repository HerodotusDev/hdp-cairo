use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use tracing::trace;
use types::{proofs::injected_state::StateProofs, ChainProofs};

use crate::vars;

pub const HINT_CHAIN_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(chain_proofs))";

pub fn hint_chain_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    trace!(hint = "hint_chain_proofs_len", "executing hint");
    let chain_proofs = exec_scopes.get::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS)?;
    insert_value_into_ap(vm, Felt252::from(chain_proofs.len()))
}

pub const HINT_CHAIN_PROOFS_CHAIN_ID: &str = "memory[ap] = to_felt_or_relocatable(chain_proofs[ids.idx - 1].chain_id)";

pub fn hint_chain_proofs_chain_id(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    trace!(hint = "hint_chain_proofs_chain_id", "executing hint");
    let chain_proofs = exec_scopes.get::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .map_err(|e| HintError::CustomHint(format!("verify: ids.idx is not a valid usize: {e}").into()))?;
    insert_value_into_ap(vm, Felt252::from(chain_proofs[idx - 1].chain_id()))
}

pub const HINT_STATE_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(state_proofs))";

pub fn hint_state_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    trace!(hint = "hint_state_proofs_len", "executing hint");
    let state_proofs = exec_scopes.get::<StateProofs>(vars::scopes::STATE_PROOFS)?;

    insert_value_into_ap(vm, Felt252::from(state_proofs.len()))
}

pub const HINT_STATE_PROOFS_PROOF_TYPE: &str = "memory[ap] = to_felt_or_relocatable(state_proofs[ids.idx - 1].proof_type)";

pub fn hint_state_proofs_proof_type(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    trace!(hint = "hint_state_proofs_proof_type", "executing hint");
    let state_proofs = exec_scopes.get::<StateProofs>(vars::scopes::STATE_PROOFS)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .map_err(|e| HintError::CustomHint(format!("verify: ids.idx is not a valid usize: {e}").into()))?;

    insert_value_into_ap(vm, state_proofs[idx - 1].get_type())
}
