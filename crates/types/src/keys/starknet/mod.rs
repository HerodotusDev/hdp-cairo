pub mod header;
pub mod storage;

use std::env;

use thiserror::Error;

use crate::{ChainId, RPC_URL_STARKNET_MAINNET, RPC_URL_STARKNET_TESTNET, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID};

#[derive(Error, Debug)]
pub enum KeyError {
    #[error("missing environment variable {var_name} for chain {chain_id}")]
    MissingEnvVar { var_name: &'static str, chain_id: ChainId },
    #[error("unsupported chain ID {chain_id}")]
    UnsupportedChainId { chain_id: ChainId },
    #[error("failed to parse {field} from felt: {value}")]
    FeltConversionFailed { field: &'static str, value: String },
}

pub trait ChainIdentifiable {
    fn chain_id(&self) -> ChainId;
}

pub fn get_corresponding_rpc_url<T: ChainIdentifiable>(key: &T) -> Result<String, KeyError> {
    match key.chain_id() {
        STARKNET_MAINNET_CHAIN_ID => env::var(RPC_URL_STARKNET_MAINNET).map_err(|_| KeyError::MissingEnvVar {
            var_name: RPC_URL_STARKNET_MAINNET,
            chain_id: STARKNET_MAINNET_CHAIN_ID,
        }),
        STARKNET_TESTNET_CHAIN_ID => env::var(RPC_URL_STARKNET_TESTNET).map_err(|_| KeyError::MissingEnvVar {
            var_name: RPC_URL_STARKNET_TESTNET,
            chain_id: STARKNET_TESTNET_CHAIN_ID,
        }),
        other => Err(KeyError::UnsupportedChainId { chain_id: other }),
    }
}
