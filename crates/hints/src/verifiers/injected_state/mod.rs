pub mod inclusion;
pub mod update;

use std::{any::Any, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::proofs::injected_state::{StateProof, StateProofRead, StateProofWrite, StateProofs};

use crate::vars;

pub const HINT_STATE_PROOF_ENTER_SCOPE: &str =
    "vm_enter_scope({'state_proof': state_proofs[ids.idx - 1], '__dict_manager': __dict_manager})";

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

    let state_proof: Box<dyn Any> = match state_proofs[idx - 1].to_owned() {
        StateProof::Read(state_proof) => Box::new(state_proof),
        StateProof::Write(state_proof) => Box::new(state_proof),
    };
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get_dict_manager()?);

    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::STATE_PROOF), state_proof),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}

pub const HINT_STATE_PROOF_READ_TRIE_LABEL: &str = "memory[ap] = to_felt_or_relocatable(state_proof_read.trie_label)";

pub fn hint_state_proof_read_trie_label(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofRead>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.trie_label.to_be_bytes()))
}

pub const HINT_STATE_PROOF_WRITE_TRIE_LABEL: &str = "memory[ap] = to_felt_or_relocatable(state_proof_write.trie_label)";

pub fn hint_state_proof_write_trie_label(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let state_proof = exec_scopes.get::<StateProofWrite>(vars::scopes::STATE_PROOF)?;
    insert_value_into_ap(vm, Felt252::from_bytes_be(&state_proof.trie_label.to_be_bytes()))
}
