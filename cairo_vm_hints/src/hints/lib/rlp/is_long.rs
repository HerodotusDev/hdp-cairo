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

const FELT_C0: Felt252 = Felt252::from_hex_unchecked("0xc0");
const FELT_F6: Felt252 = Felt252::from_hex_unchecked("0xf6");
const FELT_F7: Felt252 = Felt252::from_hex_unchecked("0xf7");
const FELT_FF: Felt252 = Felt252::from_hex_unchecked("0xff");

pub const HINT_IS_LONG: &str =
    "ids.is_long = 0 if 0xc0 <= ids.first_byte <= 0xf6 else 1 if 0xf7 <= ids.first_byte <= 0xff else assert False, 'Invalid RLP list'";

pub fn hint_is_long(
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

    let insert = if FELT_C0 <= first_byte && first_byte <= FELT_F6 {
        Felt252::ZERO
    } else if FELT_F7 <= first_byte && first_byte <= FELT_FF {
        Felt252::ONE
    } else {
        return Err(HintError::UnknownHint(
            "Invalid RLP list".to_string().into_boxed_str(),
        ));
    };

    insert_value_from_var_name(
        "is_long",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
