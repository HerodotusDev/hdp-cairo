use crate::vars;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_relocatable_from_var_name, insert_value_from_var_name};
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use std::collections::HashMap;

const FELT_TWO_POW_128: Felt252 = Felt252::from_hex_unchecked("0x0100000000000000000000000000000000");

pub const HINT_TARGET_TASK_HASH: &str =
    "target_task_hash = hex(ids.task_hash.low + ids.task_hash.high*2**128)[2:]\nprint(f\"Task Hash: 0x{target_task_hash}\")";

pub fn hint_target_task_hash(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let task_hash = vm
        .get_continuous_range(
            get_relocatable_from_var_name(vars::ids::TASK_HASH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?,
            2,
        )?
        .into_iter()
        .map(|x| x.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let target_task_hash = task_hash[0].to_biguint() + FELT_TWO_POW_128.to_biguint() * task_hash[1].to_biguint();

    println!("Task Hash: 0x{:x}", target_task_hash);

    Ok(())
}

pub const HINT_IS_LEFT_SMALLER: &str =
    "def flip_endianess(val):\n    val_hex = hex(val)[2:]\n\n    if len(val_hex) % 2:\n        val_hex = '0' + val_hex\n\n    # Convert hex string to bytes\n    byte_data = bytes.fromhex(val_hex)\n    num = int.from_bytes(byte_data, byteorder=\"little\")\n\n    return num\n\n# In LE Uint256, the low and high are reversed\nleft = flip_endianess(ids.left.low) * 2**128 + flip_endianess(ids.left.high)\nright = flip_endianess(ids.right.low) * 2**128 + flip_endianess(ids.right.high)\n\n# Compare the values to derive correct hashing order\nif left < right:\n    ids.is_left_smaller = 1\n    #print(f\"H({hex(left)}, {hex(right)})\")\nelse:\n    #print(f\"H({hex(right)}, {hex(left)})\")\n    ids.is_left_smaller = 0";

pub fn hint_is_left_smaller(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left = vm
        .get_continuous_range(
            get_relocatable_from_var_name(vars::ids::LEFT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?,
            2,
        )?
        .into_iter()
        .map(|x| x.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let right = vm
        .get_continuous_range(
            get_relocatable_from_var_name(vars::ids::RIGHT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?,
            2,
        )?
        .into_iter()
        .map(|x| x.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let left_flipped =
        BigUint::from_bytes_le(&left[0].to_bytes_be()) * FELT_TWO_POW_128.to_biguint() + BigUint::from_bytes_le(&left[1].to_bytes_be());
    let right_flipped =
        BigUint::from_bytes_le(&right[1].to_bytes_be()) * FELT_TWO_POW_128.to_biguint() + BigUint::from_bytes_le(&right[1].to_bytes_be());

    let insert = if left_flipped < right_flipped { Felt252::ONE } else { Felt252::ZERO };

    insert_value_from_var_name(
        vars::ids::IS_LEFT_SMALLER,
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
