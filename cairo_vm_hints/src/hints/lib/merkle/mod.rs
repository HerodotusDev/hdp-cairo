use crate::hints::vars;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_relocatable_from_var_name, insert_value_from_var_name,
};
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigInt;
use std::collections::HashMap;

const TWO_POW_128: Felt252 = Felt252::from_hex_unchecked("0x0100000000000000000000000000000000");

pub const HINT_TARGET_TASK_HASH: &str =
    "target_task_hash = hex(ids.task_hash.low + ids.task_hash.high*2**128)[2:] print(f\"Task Hash: 0x{target_task_hash}\")";

pub fn hint_target_task_hash(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let task_hash_ptr = get_relocatable_from_var_name(
        vars::ids::TASK_HASH,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let task_hash = vm
        .get_continuous_range(task_hash_ptr, 2)?
        .into_iter()
        .map(|x| x.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let task_hash_low = task_hash[0];
    let task_hash_high = task_hash[1];

    // 2**128
    let multiplier = BigInt::from_bytes_be(num_bigint::Sign::Plus, &TWO_POW_128.to_bytes_be());

    // task_hash_high * 2**128
    let multiplication =
        BigInt::from_bytes_be(num_bigint::Sign::Plus, &task_hash_high.to_bytes_be()) * multiplier;

    // task_hash_low + `multiplication`
    let result = BigInt::from_bytes_be(num_bigint::Sign::Plus, &task_hash_low.to_bytes_be())
        + multiplication;

    let target_task_hash = format!("{:x}", result);

    // TODO: add appropriate logger
    println!("Task Hash: 0x{}", target_task_hash);

    Ok(())
}

pub const HINT_IS_LEFT_SMALLER: &str =
    "def flip_endianess(val): val_hex = hex(val)[2:] if len(val_hex) % 2: val_hex = '0' + val_hex # Convert hex string to bytes byte_data = bytes.fromhex(val_hex) num = int.from_bytes(byte_data, byteorder=\"little\") return num # In LE Uint256, the low and high are reversed left = flip_endianess(ids.left.low) * 2**128 + flip_endianess(ids.left.high) right = flip_endianess(ids.right.low) * 2**128 + flip_endianess(ids.right.high) # Compare the values to derive correct hashing order if left < right: ids.is_left_smaller = 1 #print(f\"H({hex(left)}, {hex(right)}\") else: #print(f\"H({hex(right)}, {hex(left)}\") ids.is_left_smaller = 0";

fn flip_endianess(val: Felt252) -> Felt252 {
    let mut bytes = val.to_bytes_be();
    bytes.reverse();

    Felt252::from_bytes_be(&bytes)
}

pub fn hint_is_left_smaller(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left_ptr = get_relocatable_from_var_name(
        vars::ids::LEFT,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let left = vm
        .get_continuous_range(left_ptr, 2)?
        .into_iter()
        .map(|x| x.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let left_low = left[0];
    let left_high = left[1];

    let right_ptr = get_relocatable_from_var_name(
        vars::ids::RIGHT,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let right = vm
        .get_continuous_range(right_ptr, 2)?
        .into_iter()
        .map(|x| x.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let right_low = right[0];
    let right_high = right[1];

    let left_flipped = flip_endianess(left_low) * TWO_POW_128 + flip_endianess(left_high);
    let right_flipped = flip_endianess(right_low) * TWO_POW_128 + flip_endianess(right_high);

    let insert = if left_flipped < right_flipped {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };

    insert_value_from_var_name(
        vars::ids::IS_LEFT_SMALLER,
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
