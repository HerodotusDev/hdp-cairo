use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_integer_from_var_name, insert_value_from_var_name,
};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::cmp::Ordering;
use std::collections::HashMap;

pub const HINT_HAS_TYPE_PREFIX: &str =
    "ids.has_type_prefix = 1 if 0x0 < ids.first_byte < 0x04 else 0";

pub fn hint_has_type_prefix(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let first_byte = get_integer_from_var_name(
        "first_byte",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    match first_byte.cmp(&Felt252::ZERO) {
        Ordering::Less | Ordering::Equal => {
            insert_value_from_var_name(
                "has_type_prefix",
                MaybeRelocatable::Int(Felt252::ZERO),
                vm,
                &hint_data.ids_data,
                &hint_data.ap_tracking,
            )?;
        }
        Ordering::Greater => match first_byte.cmp(&Felt252::from_hex_unchecked("0x04")) {
            Ordering::Less => {
                insert_value_from_var_name(
                    "has_type_prefix",
                    MaybeRelocatable::Int(Felt252::ONE),
                    vm,
                    &hint_data.ids_data,
                    &hint_data.ap_tracking,
                )?;
            }
            Ordering::Equal | Ordering::Greater => {
                insert_value_from_var_name(
                    "has_type_prefix",
                    MaybeRelocatable::Int(Felt252::ZERO),
                    vm,
                    &hint_data.ids_data,
                    &hint_data.ap_tracking,
                )?;
            }
        },
    };

    Ok(())
}

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        HINT_HAS_TYPE_PREFIX => hint_has_type_prefix(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
