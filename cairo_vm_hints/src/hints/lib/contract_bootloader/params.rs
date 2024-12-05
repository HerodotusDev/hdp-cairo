use crate::{hint_processor::models::Param, hints::vars};
use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_ptr_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const LOAD_PARMAS: &str = "ids.params_len = len(params)\nsegments.write_arg(ids.params, [param.value for param in params])";

pub fn load_parmas(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let params = exec_scopes.get::<Vec<Param>>(vars::scopes::PARAMS)?;
    insert_value_from_var_name(vars::ids::PARAMS_LEN, params.len(), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let params_base = get_ptr_from_var_name(vars::ids::PARAMS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    write_params(vm, params_base, params)?;

    Ok(())
}

pub fn write_params(vm: &mut VirtualMachine, ptr: Relocatable, params: Vec<Param>) -> Result<(), HintError> {
    for (idx, param) in params.into_iter().enumerate() {
        vm.insert_value((ptr + idx)?, param.value)?;
    }

    Ok(())
}
