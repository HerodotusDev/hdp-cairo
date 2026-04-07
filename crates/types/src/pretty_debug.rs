//! Decode Cairo `DebugPrint` felts as human-readable short-string text.

use crate::Felt252;

/// Reconstruct a clean debug message from a DebugPrint felt range.
/// Each felt is tried as a Cairo short string (up to 31 ASCII bytes);
/// printable fragments are concatenated into a single line.
pub fn pretty_debug_text(felts: &[Felt252]) -> String {
    let mut text = String::new();
    for value in felts {
        if let Some(s) = felt_as_short_string(value) {
            text.push_str(&s);
        }
    }
    text
}

/// Decode a Felt252 as a Cairo short string (same idea as cairo-vm's
/// `as_cairo_short_string`). Returns None if any byte is non-ASCII.
pub fn felt_as_short_string(value: &Felt252) -> Option<String> {
    let mut result = String::new();
    let mut ended = false;
    for byte in value.to_bytes_be().into_iter().skip_while(|b| *b == 0) {
        if byte == 0 {
            ended = true;
        } else if ended || !byte.is_ascii() {
            return None;
        } else {
            result.push(byte as char);
        }
    }
    Some(result)
}
