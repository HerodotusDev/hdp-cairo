use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_traits::ToPrimitive;

/// Hint to convert BytecodeLeWords from unconstrained memorizer to RLP format for evm memorizer.
/// 
/// BytecodeLeWords format in memory:
/// - [0]: words_64bit_len (number of 64-bit words)
/// - [1..len]: 64-bit words (little-endian bytes, 8 bytes each)
/// - [len+1]: last_input_word (remaining bytes in LE)
/// - [len+2]: last_input_num_bytes
///
/// RLP format for code_decoder.cairo:
/// - Each felt contains 8 bytes in big-endian order
/// - RLP string: [0x80 + len] + bytes (short) or [0xb7 + len_of_len] + len_bytes + bytes (long)
// The hint code MUST match the Cairo hint exactly (character for character)
pub const HINT_BYTECODE_LE_WORDS_TO_RLP: &str = r#"# Convert BytecodeLeWords to RLP format
words_64bit_len = ids.words_64bit_len
last_input_word = ids.last_input_word
last_input_num_bytes = ids.last_input_num_bytes

# Unpack all bytes from 64-bit LE words
raw_bytes = []
for i in range(words_64bit_len):
    word = memory[ids.words_64bit_ptr + i]
    for b in range(8):
        raw_bytes.append((word >> (b * 8)) & 0xff)

# Add remaining bytes from last_input_word
for b in range(last_input_num_bytes):
    raw_bytes.append((last_input_word >> (b * 8)) & 0xff)

total_len = len(raw_bytes)

# Build RLP encoding
if total_len == 0:
    rlp_bytes = [0x80]
elif total_len == 1 and raw_bytes[0] <= 0x7f:
    rlp_bytes = raw_bytes
elif total_len < 56:
    rlp_bytes = [0x80 + total_len] + raw_bytes
else:
    # Long string
    len_bytes_list = []
    temp_len = total_len
    while temp_len > 0:
        len_bytes_list.insert(0, temp_len % 256)
        temp_len = temp_len // 256
    rlp_bytes = [0xb7 + len(len_bytes_list)] + len_bytes_list + raw_bytes

# Pack into 8-byte LE felts (as expected by code_decoder which uses extract_byte_at_pos from rlp_little)
# extract_byte_at_pos reads from LSB (little-endian), so we need to pack bytes in LE order
num_felts = (len(rlp_bytes) + 7) // 8
for i in range(num_felts):
    felt_val = 0
    for j in range(8):
        idx = i * 8 + j
        byte_val = rlp_bytes[idx] if idx < len(rlp_bytes) else 0
        # Pack as LE: first byte goes to LSB, last byte goes to MSB
        felt_val = felt_val | (byte_val << (j * 8))
    memory[ids.rlp_data + i] = felt_val
ids.rlp_num_felts = num_felts"#;

pub fn hint_bytecode_le_words_to_rlp(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
        get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name,
    };

    let ids = &hint_data.ids_data;
    let ap_tracking = &hint_data.ap_tracking;

    // Get variables from Cairo
    let words_64bit_len: usize = get_integer_from_var_name("words_64bit_len", vm, ids, ap_tracking)?
        .to_usize()
        .ok_or_else(|| HintError::CustomHint("words_64bit_len too large".into()))?;

    let last_input_word = get_integer_from_var_name("last_input_word", vm, ids, ap_tracking)?;
    let last_input_num_bytes: usize =
        get_integer_from_var_name("last_input_num_bytes", vm, ids, ap_tracking)?
            .to_usize()
            .ok_or_else(|| HintError::CustomHint("last_input_num_bytes too large".into()))?;

    let words_64bit_ptr = get_ptr_from_var_name("words_64bit_ptr", vm, ids, ap_tracking)?;
    let rlp_data = get_ptr_from_var_name("rlp_data", vm, ids, ap_tracking)?;

    // Unpack all bytes from 64-bit LE words
    let mut raw_bytes: Vec<u8> = Vec::with_capacity(words_64bit_len * 8 + last_input_num_bytes);

    for i in 0..words_64bit_len {
        let word = vm.get_integer((words_64bit_ptr + i)?)?;
        let word_val = word.to_u64().unwrap_or(0);
        for b in 0..8 {
            raw_bytes.push(((word_val >> (b * 8)) & 0xff) as u8);
        }
    }

    // Add remaining bytes from last_input_word
    let last_word_val = last_input_word.to_u64().unwrap_or(0);
    for b in 0..last_input_num_bytes {
        raw_bytes.push(((last_word_val >> (b * 8)) & 0xff) as u8);
    }

    let total_len = raw_bytes.len();
    
    // Debug logging (before moving raw_bytes)
    eprintln!("[DEBUG bridge_bytecode_to_evm] words_64bit_len={}, last_input_num_bytes={}, total_bytes={}", 
              words_64bit_len, last_input_num_bytes, total_len);
    if total_len > 0 {
        let first_bytes: Vec<u8> = raw_bytes.iter().take(32).copied().collect();
        eprintln!("[DEBUG bridge_bytecode_to_evm] First 32 bytes of bytecode: {:02x?}", first_bytes);
    }

    // Build RLP encoding
    let rlp_bytes: Vec<u8> = if total_len == 0 {
        vec![0x80]
    } else if total_len == 1 && raw_bytes[0] <= 0x7f {
        raw_bytes
    } else if total_len < 56 {
        let mut result = vec![0x80 + total_len as u8];
        result.extend(raw_bytes);
        result
    } else {
        // Long string
        let mut len_bytes_list: Vec<u8> = Vec::new();
        let mut temp_len = total_len;
        while temp_len > 0 {
            len_bytes_list.insert(0, (temp_len % 256) as u8);
            temp_len /= 256;
        }

        let mut result = vec![0xb7 + len_bytes_list.len() as u8];
        result.extend(len_bytes_list);
        result.extend(raw_bytes);
        result
    };

    // Pack into 8-byte LE felts (as expected by code_decoder which uses extract_byte_at_pos from rlp_little)
    // extract_byte_at_pos reads from LSB (little-endian), so we need to pack bytes in LE order
    let num_felts = (rlp_bytes.len() + 7) / 8;
    for i in 0..num_felts {
        let mut felt_val: u64 = 0;
        for j in 0..8 {
            let idx = i * 8 + j;
            let byte_val = if idx < rlp_bytes.len() {
                rlp_bytes[idx] as u64
            } else {
                0
            };
            // Pack as LE: first byte goes to LSB, last byte goes to MSB
            felt_val = felt_val | (byte_val << (j * 8));
        }
        vm.insert_value((rlp_data + i)?, Felt252::from(felt_val))?;
    }

    // Write num_felts back to Cairo
    insert_value_from_var_name("rlp_num_felts", Felt252::from(num_felts), vm, ids, ap_tracking)?;
    
    // Debug logging
    eprintln!("[DEBUG bridge_bytecode_to_evm] RLP bytes length={}, num_felts={}", rlp_bytes.len(), num_felts);
    
    // Try to get the evm_key if it's available in the hint context
    // Note: The key is computed in Cairo, so we can't easily access it here
    // But we can log the address and other params if available
    if let Ok(chain_id) = get_integer_from_var_name("chain_id", vm, ids, ap_tracking) {
        if let Ok(block_number) = get_integer_from_var_name("block_number", vm, ids, ap_tracking) {
            if let Ok(address) = get_integer_from_var_name("address", vm, ids, ap_tracking) {
                eprintln!("[DEBUG bridge_bytecode_to_evm] Storing bytecode with params: chain_id={}, block_number={}, address={}", 
                         chain_id, block_number, address);
            }
        }
    }

    Ok(())
}

