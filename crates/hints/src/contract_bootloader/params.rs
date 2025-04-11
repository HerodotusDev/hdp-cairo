use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use crate::vars;

pub const LOAD_PUBLIC_INPUTS: &str = "segments.write_arg(ids.public_inputs, public_inputs)";
pub const LOAD_PUBLIC_INPUTS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(public_inputs))";
pub const LOAD_PRIVATE_INPUTS: &str = "segments.write_arg(ids.private_inputs, private_inputs)";
pub const LOAD_PRIVATE_INPUTS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(private_inputs))";

pub fn load_public_inputs(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PUBLIC_INPUTS)?;
    let inputs_base = get_ptr_from_var_name(vars::ids::PUBLIC_INPUTS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.load_data(inputs_base, &inputs.iter().map(MaybeRelocatable::from).collect::<Vec<_>>())?;
    Ok(())
}

pub fn load_public_inputs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PUBLIC_INPUTS)?;
    insert_value_into_ap(vm, inputs.len())?;
    Ok(())
}

pub fn load_private_inputs(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PRIVATE_INPUTS)?;
    let inputs_base = get_ptr_from_var_name(vars::ids::PRIVATE_INPUTS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.load_data(inputs_base, &inputs.iter().map(MaybeRelocatable::from).collect::<Vec<_>>())?;
    Ok(())
}

pub fn load_private_inputs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PRIVATE_INPUTS)?;
    insert_value_into_ap(vm, inputs.len())?;
    Ok(())
}
