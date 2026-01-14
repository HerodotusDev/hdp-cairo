// PUSH opcode hint - reads bytes from bytecode and constructs Uint256

use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use num_traits::ToPrimitive;

pub const HINT_READ_PUSH_VALUE: &str = r#"val = 0
for b in range(ids.n):
    val = (val << 8) | memory[ids.bytecode + ids.start + b]

ids.value_low = val & ((1 << 128) - 1)
ids.value_high = val >> 128

if 0: # Set to 1 for verbose push logging
    print(f"PUSH{ids.n} value: {hex(val)}")"#;

pub fn hint_read_push_value(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let bytecode_ptr = get_ptr_from_var_name("bytecode", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let start_val = get_integer_from_var_name("start", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let start = start_val
        .to_biguint()
        .to_usize()
        .ok_or_else(|| HintError::CustomHint("start too large".into()))?;
    let n_val = get_integer_from_var_name("n", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let n = n_val
        .to_biguint()
        .to_usize()
        .ok_or_else(|| HintError::CustomHint("n too large".into()))?;

    // Read n bytes from bytecode starting at start
    // Bytecode is stored as felt* where each felt is a byte (0-255)
    let mut val = BigUint::from(0u32);
    for b in 0..n {
        let idx = start + b;
        let byte_addr = (bytecode_ptr + idx)?;
        let byte_felt = vm.get_integer(byte_addr)?;
        let byte_val = byte_felt.to_u8().unwrap_or(0) as u64;
        
        // Build 256-bit value (big-endian: first byte is MSB)
        val = (val << 8) | BigUint::from(byte_val);
    }

    // Split into low (128 bits) and high (128 bits)
    let mask_128 = (BigUint::from(1u32) << 128u32) - BigUint::from(1u32);
    let value_low: BigUint = &val & &mask_128;
    let value_high: BigUint = &val >> 128u32;

    // Convert to Felt252 and write back
    // Felt252::from_bytes_be needs a [u8; 32] array, so we pad to 32 bytes
    let mut low_bytes = value_low.to_bytes_be();
    let mut high_bytes = value_high.to_bytes_be();
    low_bytes.resize(32, 0);
    high_bytes.resize(32, 0);
    
    let mut low_array = [0u8; 32];
    let mut high_array = [0u8; 32];
    low_array.copy_from_slice(&low_bytes[..32]);
    high_array.copy_from_slice(&high_bytes[..32]);
    
    let value_low_felt = Felt252::from_bytes_be(&low_array);
    let value_high_felt = Felt252::from_bytes_be(&high_array);

    insert_value_from_var_name("value_low", MaybeRelocatable::Int(value_low_felt), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("value_high", MaybeRelocatable::Int(value_high_felt), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    Ok(())
}

