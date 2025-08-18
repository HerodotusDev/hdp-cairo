use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::get_integer_from_var_name},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::proofs::injected_state::StateProofWrite;

use crate::vars;

pub const HINT_GET_UPDATE_PROOF_AT: &str = "ids.update = state_proof_wrapper.state_proof.update";

pub fn hint_get_update_proof_at(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let _state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    let _idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    Ok(())
}
