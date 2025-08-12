pub mod inclusion_verifier;
pub mod non_inclusion_verifier;
pub mod update_verifier;

use std::{any::Any, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::get_integer_from_var_name},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::proofs::state::StateProofs;

use crate::vars;

pub const HINT_STATE_PROOF_ENTER_SCOPE: &str =
    "vm_enter_scope({'state_proof_wrapper': state_proofs[ids.idx - 1], '__dict_manager': __dict_manager})";

pub fn hint_state_proof_enter_scope(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proofs = exec_scopes.get::<StateProofs>(vars::scopes::STATE_PROOFS)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    // let batch: Box<dyn Any> = match state_proofs[idx - 1].state_proof.clone() {
    //     StateProof::Inclusion(proofs) => Box::new(proofs),
    //     StateProof::NonInclusion(proofs) => Box::new(proofs),
    //     StateProof::Update(proofs) => Box::new(proofs),
    // };
    let state_proof_wrapper: Box<dyn Any> = Box::new(state_proofs[idx - 1].clone());
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get_dict_manager()?);

    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::STATE_PROOF_WRAPPER), state_proof_wrapper),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}
