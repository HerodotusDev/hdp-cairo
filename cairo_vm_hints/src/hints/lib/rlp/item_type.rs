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

const FELT_7F: Felt252 = Felt252::from_hex_unchecked("0x7f");
const FELT_80: Felt252 = Felt252::from_hex_unchecked("0x80");
const FELT_B6: Felt252 = Felt252::from_hex_unchecked("0xb6");
const FELT_B7: Felt252 = Felt252::from_hex_unchecked("0xb7");
const FELT_BF: Felt252 = Felt252::from_hex_unchecked("0xbf");
const FELT_C0: Felt252 = Felt252::from_hex_unchecked("0xc0");
const FELT_F6: Felt252 = Felt252::from_hex_unchecked("0xf6");
const FELT_F7: Felt252 = Felt252::from_hex_unchecked("0xf7");
const FELT_FF: Felt252 = Felt252::from_hex_unchecked("0xff");
const FELT_FOUR: Felt252 = Felt252::from_hex_unchecked("0x04");

pub const HINT_ITEM_TYPE: &str = "ids.item_type = 0 if ids.current_item <= 0x7f else 1 if 0x80 <= ids.current_item <= 0xb6 else 2 if 0xb7 <= ids.current_item <= 0xbf else 3 if 0xc0 <= ids.current_item <= 0xf6 else 4 if 0xf7 <= ids.current_item <= 0xff else assert False, 'Invalid RLP item'";

pub fn hint_item_type(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let current_item = get_integer_from_var_name(
        "current_item",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let insert = if current_item <= FELT_7F {
        Felt252::ZERO
    } else if FELT_80 <= current_item && current_item <= FELT_B6 {
        Felt252::ONE // short string
    } else if FELT_B7 <= current_item && current_item <= FELT_BF {
        Felt252::TWO // long string
    } else if FELT_C0 <= current_item && current_item <= FELT_F6 {
        Felt252::THREE // short list
    } else if FELT_F7 <= current_item && current_item <= FELT_FF {
        FELT_FOUR // long list
    } else {
        return Err(HintError::UnknownHint(
            "Invalid RLP item".to_string().into_boxed_str(),
        ));
    };

    insert_value_from_var_name(
        "item_type",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
