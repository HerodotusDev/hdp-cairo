// Bytecode conversion hints for EVM executor

use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use num_traits::ToPrimitive;

/// Convert BytecodeLeWords format to RLP format
/// 
/// Input variables:
/// - words_64bit_len: Number of 64-bit words
/// - words_64bit_ptr: Pointer to array of 64-bit words
/// - last_input_word: Last word value
/// - last_input_num_bytes: Number of bytes in last word
/// 
/// Output variables:
/// - rlp_data: Pointer to output RLP data (allocated by caller)
/// - rlp_num_felts: Number of felts in RLP output
pub const HINT_BYTECODE_TO_RLP: &str = r#"# Convert BytecodeLeWords to RLP format
# This hint is implemented in Rust - see hint_bytecode_to_rlp function"#;

pub fn hint_bytecode_to_rlp(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // Read input variables
    let words_64bit_len = get_integer_from_var_name("words_64bit_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let words_64bit_ptr = get_ptr_from_var_name("words_64bit_ptr", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let last_input_word = get_integer_from_var_name("last_input_word", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_biguint();
    let last_input_num_bytes = get_integer_from_var_name("last_input_num_bytes", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let rlp_data = get_ptr_from_var_name("rlp_data", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    // Unpack all bytes from 64-bit LE words
    let mut raw_bytes = Vec::new();
    
    // Read words from memory
    for i in 0..words_64bit_len {
        let word_addr = (words_64bit_ptr + i)?;
        let word_felt = vm.get_integer(word_addr)?;
        let word = word_felt.to_biguint();
        
        // Extract 8 bytes (little-endian)
        for b in 0..8 {
            let shift: u32 = b * 8;
            let mask = BigUint::from(0xFFu8);
            let shifted: BigUint = &word >> shift;
            let masked: BigUint = &shifted & &mask;
            let byte = masked.to_u8().unwrap_or(0);
            raw_bytes.push(byte);
        }
    }

    // Add remaining bytes from last_input_word
    for b in 0..last_input_num_bytes {
        let shift: u32 = (b * 8) as u32;
        let mask = BigUint::from(0xFFu8);
        let shifted: BigUint = &last_input_word >> shift;
        let masked: BigUint = &shifted & &mask;
        let byte = masked.to_u8().unwrap_or(0);
        raw_bytes.push(byte);
    }

    let total_len = raw_bytes.len();

    // Build RLP encoding
    let rlp_bytes = if total_len == 0 {
        vec![0x80]
    } else if total_len == 1 && raw_bytes[0] <= 0x7f {
        raw_bytes
    } else if total_len < 56 {
        let mut result = vec![0x80 + total_len as u8];
        result.extend_from_slice(&raw_bytes);
        result
    } else {
        // Long string encoding
        let mut len_bytes_list = Vec::new();
        let mut temp_len = total_len;
        while temp_len > 0 {
            len_bytes_list.insert(0, (temp_len % 256) as u8);
            temp_len = temp_len / 256;
        }
        let mut result = vec![0xb7 + len_bytes_list.len() as u8];
        result.extend_from_slice(&len_bytes_list);
        result.extend_from_slice(&raw_bytes);
        result
    };

    // Pack into 8-byte LE felts (as expected by code_decoder)
    // extract_byte_at_pos reads from LSB (little-endian), so we need to pack bytes in LE order
    let num_felts = (rlp_bytes.len() + 7) / 8;
    
    for i in 0..num_felts {
        let mut felt_val = BigUint::from(0u8);
        for j in 0..8 {
            let idx = i * 8 + j;
            let byte_val = if idx < rlp_bytes.len() { rlp_bytes[idx] } else { 0 };
            // Pack as LE: first byte goes to LSB, last byte goes to MSB
            let shift: u32 = (j * 8) as u32;
            felt_val = felt_val | (BigUint::from(byte_val) << shift);
        }
        
        // Convert BigUint to Felt252
        // Pad to 32 bytes for Felt252::from_bytes_be
        let mut bytes = felt_val.to_bytes_be();
        if bytes.len() > 32 {
            // Truncate if too large (shouldn't happen for 8-byte values)
            bytes = bytes[bytes.len() - 32..].to_vec();
        }
        bytes.resize(32, 0);
        let mut byte_array = [0u8; 32];
        byte_array.copy_from_slice(&bytes[..32]);
        let felt = Felt252::from_bytes_be(&byte_array);
        
        let dst_addr = (rlp_data + i)?;
        vm.insert_value(dst_addr, felt)?;
    }

    // Write rlp_num_felts
    insert_value_from_var_name("rlp_num_felts", Felt252::from(num_felts), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    Ok(())
}
