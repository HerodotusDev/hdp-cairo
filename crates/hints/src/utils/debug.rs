use std::collections::HashMap;
use types::cairo::traits::CairoType;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::{get_address_from_var_name, get_integer_from_var_name, get_ptr_from_var_name, get_reference_from_var_name}},
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use crate::python::garaga::types::UInt384;

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

pub const PRINT_UINT384: &str = "print(f\"{hex(ids.value.d3 * 2 ** 144 + ids.value.d2 * 2 ** 96 + ids.value.d1 * 2 ** 48 + ids.value.d0)}\")";

pub fn print_uint384(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let ptr: MaybeRelocatable = get_address_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    if let MaybeRelocatable::RelocatableValue(ptr) = ptr {
        let value = UInt384::from_memory(vm, ptr)?;
        let bytes = value.to_bytes();
      
          println!("Value: 0x{}", hex::encode(bytes));
    } 
    // ToDo: error handling
    Ok(())
}