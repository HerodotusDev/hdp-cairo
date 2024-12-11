use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData, dict_manager::DictManager, hint_utils::insert_value_from_var_name,
    },
    types::relocatable::MaybeRelocatable,
};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{any::Any, collections::HashMap};

use crate::{hint_processor::models::proofs::Proofs, hints::vars};

pub const HINT_BATCH_LEN: &str = "ids.batch_len = len(ids.proofs)";

pub fn hint_batch_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Vec<Proofs>>(vars::scopes::PROOFS)?;

    insert_value_from_var_name(
        vars::ids::BATCH_LEN,
        MaybeRelocatable::Int(proofs.len().into()),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_CHAIN_ID: &str = "ids.chain_id = proofs[ids.batch_len - 1].mmr_meta.chain_id";

pub fn hint_chain_id(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Vec<Proofs>>(vars::scopes::PROOFS)?;

    let chain_id = proofs[proofs.len() - 1].mmr_meta.chain_id;

    insert_value_from_var_name(
        vars::ids::CHAIN_ID,
        MaybeRelocatable::Int(chain_id.into()),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'batch': proofs[ids.batch_len - 1], '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Vec<Proofs>>(vars::scopes::PROOFS)?;

    let batch: Box<dyn Any> = Box::new(proofs[proofs.len() - 1].clone());
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get::<DictManager>(vars::scopes::DICT_MANAGER)?);
    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::BATCH), batch),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}
