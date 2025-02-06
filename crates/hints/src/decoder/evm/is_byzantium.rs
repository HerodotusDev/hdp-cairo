use std::{cmp::Ordering, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

const BYZANTIUM_START_BLOCK_NUMBER: Felt252 = Felt252::from_hex_unchecked("0x42AE50");

pub const HINT_IS_BYZANTIUM: &str =
    "if ids.block_number >= ids.chain_info.byzantium:\n    ids.is_byzantium = 1\nelse:\n    ids.is_byzantium = 0";

pub fn hint_is_byzantium(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let insert = match get_integer_from_var_name("block_number", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .cmp(&BYZANTIUM_START_BLOCK_NUMBER)
    {
        Ordering::Equal | Ordering::Greater => Felt252::ONE,
        Ordering::Less => Felt252::ZERO,
    };

    insert_value_from_var_name(
        "is_byzantium",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
