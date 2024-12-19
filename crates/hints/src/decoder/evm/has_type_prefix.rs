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

pub const HINT_HAS_TYPE_PREFIX: &str = "# typed transactions have a type prefix in this range [1, 3]\nif 0x0 < ids.first_byte < 0x04:\n    ids.has_type_prefix = 1\nelse:\n    ids.has_type_prefix = 0";

pub fn hint_has_type_prefix(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let first_byte = get_integer_from_var_name("first_byte", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if Felt252::ZERO < first_byte && first_byte < FELT_4 {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };

    insert_value_from_var_name(
        "has_type_prefix",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
