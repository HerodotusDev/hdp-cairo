use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

const FELT_4: Felt252 = Felt252::from_hex_unchecked("0x04");

pub const HINT_HAS_TYPE_PREFIX: &str = "ids.has_type_prefix = 1 if 0x0 < ids.first_byte < 0x04 else 0";

pub fn hint_has_type_prefix(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let first_byte = get_integer_from_var_name("first_byte", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if Felt252::ZERO < first_byte && first_byte < FELT_4 {
        Felt252::ZERO
    } else {
        Felt252::ONE
    };

    insert_value_from_var_name(
        "has_type_prefix",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
