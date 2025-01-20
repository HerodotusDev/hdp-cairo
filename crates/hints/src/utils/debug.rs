use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const PRINT_FELT_HEX: &str = "print(f\"{hex(ids.value)}\")";

pub fn print_felt_hex(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value = get_integer_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    println!("Value: {}", value.to_hex_string());
    Ok(())
}

pub const PRINT_FELT: &str = "print(f\"{ids.value}\")";

pub fn print_felt(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value = get_integer_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    println!("Value: {}", value);
    Ok(())
}

pub const PRINT_STRING: &str = "print(f\"String: {ids.value}\")";

pub fn print_string(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {

    let value = get_integer_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let bytes = value.to_bytes_be();
    let ascii = String::from_utf8_lossy(&bytes);
    println!("String: {}", ascii);
    Ok(())
}