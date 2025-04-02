pub mod account;
pub mod header;
pub mod log;
pub mod receipt;
pub mod storage;
pub mod transaction;

use std::env;

use cairo_vm::Felt252;
use thiserror::Error;

use crate::{ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, RPC_URL_ETHEREUM, RPC_URL_ETHEREUM_SEPOLIA};

pub const BLOCK_TX_LABEL: Felt252 = Felt252::from_hex_unchecked("0x626c6f636b5f7478"); // hex val of 'block_tx'
pub const BLOCK_RECEIPT_LABEL: Felt252 = Felt252::from_hex_unchecked("0x626c6f636b5f72656365697074"); // hex val of 'block_receipt'

#[derive(Error, Debug)]
pub enum KeyError {
    #[error("Conversion Error: {0}")]
    ConversionError(String),
}

pub trait ChainIdentifiable {
    fn chain_id(&self) -> u128;
}

pub fn get_corresponding_rpc_url<T: ChainIdentifiable>(key: &T) -> Result<String, KeyError> {
    match key.chain_id() {
        ETHEREUM_MAINNET_CHAIN_ID => Ok(env::var(RPC_URL_ETHEREUM).unwrap()),
        ETHEREUM_TESTNET_CHAIN_ID => Ok(env::var(RPC_URL_ETHEREUM_SEPOLIA).unwrap()),
        _ => Err(KeyError::ConversionError("Unsupported evm chain id".into())),
    }
}
