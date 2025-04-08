pub mod header;
pub mod storage;

use std::env;

use thiserror::Error;

use crate::{RPC_URL_STARKNET, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID};

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
        STARKNET_MAINNET_CHAIN_ID => Ok(env::var(RPC_URL_STARKNET).unwrap()),
        STARKNET_TESTNET_CHAIN_ID => Ok(env::var(RPC_URL_STARKNET).unwrap()),
        _ => Err(KeyError::ConversionError("Unsupported starknet chain id".into())),
    }
}
