use cairo_vm::Felt252;

pub mod label;
pub mod read;
pub mod write;

pub const INCLUSION: Felt252 = Felt252::from_hex_unchecked("0x696E636C7573696F6E");
pub const LABEL_RUNTIME: Felt252 = Felt252::from_hex_unchecked("0x6c6162656c5f72756e74696d65");
pub const NON_INCLUSION: Felt252 = Felt252::from_hex_unchecked("0x6E6F6E5F696E636C7573696F6E");
pub const WRITE: Felt252 = Felt252::from_hex_unchecked("0x7772697465");
