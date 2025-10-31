use std::cmp::min;

use cairo_vm::vm::errors::hint_errors::HintError;

pub mod evm;
pub mod injected_state;
pub mod mpt;
pub mod starknet;
pub mod verify;

pub fn bytes_to_u256_be(value: &[u8]) -> Result<[u8; 32], HintError> {
    let mut wide = [0u8; 32];
    let src_len = value.len();
    let copy_len = min(src_len, 32);

    // Copy the last `copy_len` bytes from `src` into the last `copy_len` bytes of `wide`
    // This handles both truncation (if src > 32) and left-padding (if src < 32).
    wide[32 - copy_len..].copy_from_slice(&value[src_len - copy_len..]);

    Ok(wide)
}
