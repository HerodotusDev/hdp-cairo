use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use super::*;
use crate::vars;

pub const HINT_IS_LONG: &str = r#"if 0xc0 <= ids.first_byte <= 0xf7:
    ids.is_long = 0 # short list
elif 0xf8 <= ids.first_byte <= 0xff:
    ids.is_long = 1 # long list
else:
    assert False, "Invalid RLP list""#;

pub fn hint_is_long(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let first_byte = get_integer_from_var_name(vars::ids::FIRST_BYTE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if FELT_C0 <= first_byte && first_byte <= FELT_F7 {
        Felt252::ZERO
    } else if FELT_F8 <= first_byte && first_byte <= FELT_FF {
        Felt252::ONE
    } else {
        return Err(HintError::UnknownIdentifier("Invalid RLP list".to_string().into_boxed_str()));
    };

    insert_value_from_var_name(
        vars::ids::IS_LONG,
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_ITEM_TYPE: &str = r#"if ids.current_item <= 0x7f:
    ids.item_type = 0 # single byte [0x00, 0x7f]
elif 0x80 <= ids.current_item <= 0xb7:
    ids.item_type = 1 # short string [0x80, 0xb7]
elif 0xb8 <= ids.current_item <= 0xbf:
    ids.item_type = 2 # long string [0xb8, 0xbf]
elif 0xc0 <= ids.current_item <= 0xf7:
    ids.item_type = 3 # short list [0xc0, 0xf7]
elif 0xf8 <= ids.current_item <= 0xff:
    ids.item_type = 4 # long list [0xf8, 0xff]
else:
    assert False, "Invalid RLP item prefix""#;

pub fn hint_item_type(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let current_item = get_integer_from_var_name(vars::ids::CURRENT_ITEM, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if current_item <= FELT_7F {
        Felt252::ZERO // single byte
    } else if FELT_80 <= current_item && current_item <= FELT_B7 {
        Felt252::ONE // short string
    } else if FELT_B8 <= current_item && current_item <= FELT_BF {
        Felt252::TWO // long string
    } else if FELT_C0 <= current_item && current_item <= FELT_F7 {
        Felt252::THREE // short list
    } else if FELT_F8 <= current_item && current_item <= FELT_FF {
        FELT_4 // long list
    } else {
        return Err(HintError::UnknownIdentifier("Invalid RLP item".to_string().into_boxed_str()));
    };

    insert_value_from_var_name(
        vars::ids::ITEM_TYPE,
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
