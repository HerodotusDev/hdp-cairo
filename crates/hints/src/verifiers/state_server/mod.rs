use std::{any::Any, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::proofs::state::{StateProof, StateProofs};

use crate::vars;

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'state_proof': state_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager})";

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
        StateProof::Update(proofs) => Box::new(proofs),
    };
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get_dict_manager()?);

    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::BATCH_SERVER), batch),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}
