pub mod account;
pub mod header;
pub mod log;
pub mod receipt;
pub mod storage;
pub mod transaction;

use cairo_vm::Felt252;
use thiserror::Error;

pub const BLOCK_TX_LABEL: Felt252 = Felt252::from_hex_unchecked("0x626c6f636b5f7478"); // hex val of 'block_tx'
pub const BLOCK_RECEIPT_LABEL: Felt252 = Felt252::from_hex_unchecked("0x626c6f636b5f72656365697074"); // hex val of 'block_receipt'

#[derive(Error, Debug)]
pub enum KeyError {
    #[error("Conversion Error: {0}")]
    ConversionError(String),
}
