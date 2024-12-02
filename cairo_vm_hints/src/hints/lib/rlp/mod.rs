pub mod divmod;
pub mod item_type;
pub mod processed_words;

use cairo_vm::Felt252;

pub const FELT_4: Felt252 = Felt252::from_hex_unchecked("0x04");
pub const FELT_7F: Felt252 = Felt252::from_hex_unchecked("0x7f");
pub const FELT_80: Felt252 = Felt252::from_hex_unchecked("0x80");
pub const FELT_B6: Felt252 = Felt252::from_hex_unchecked("0xb6");
pub const FELT_B7: Felt252 = Felt252::from_hex_unchecked("0xb7");
pub const FELT_BF: Felt252 = Felt252::from_hex_unchecked("0xbf");
pub const FELT_C0: Felt252 = Felt252::from_hex_unchecked("0xc0");
pub const FELT_F6: Felt252 = Felt252::from_hex_unchecked("0xf6");
pub const FELT_F7: Felt252 = Felt252::from_hex_unchecked("0xf7");
pub const FELT_FF: Felt252 = Felt252::from_hex_unchecked("0xff");
