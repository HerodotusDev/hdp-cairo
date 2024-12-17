use crate::{hint_processor::models::proofs::Proofs, hints::vars};
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::insert_value_into_ap;
use cairo_vm::hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, dict_manager::DictManager};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{any::Any, collections::HashMap};

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'batch': proofs, '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Proofs>(vars::scopes::PROOFS)?;

    let batch: Box<dyn Any> = Box::new(proofs);
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get::<DictManager>(vars::scopes::DICT_MANAGER)?);
    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::BATCH), batch),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}

pub const HINT_HEADERS_WITH_MMR_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.headers_with_mmr))";

pub fn hint_headers_with_mmr_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Proofs>(vars::scopes::PROOF)?;

    insert_value_into_ap(vm, Felt252::from(proofs.headers_with_mmr.len()))
}
