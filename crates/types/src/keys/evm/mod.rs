pub mod account;
pub mod header;
pub mod log;
pub mod receipt;
pub mod storage;
pub mod transaction;

use std::env;

use cairo_vm::Felt252;
use thiserror::Error;

use crate::{
    ChainId, ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID,
    RPC_URL_ETHEREUM_MAINNET, RPC_URL_ETHEREUM_TESTNET, RPC_URL_OPTIMISM_MAINNET, RPC_URL_OPTIMISM_TESTNET,
};

pub const BLOCK_TX_LABEL: Felt252 = Felt252::from_hex_unchecked("0x626c6f636b5f7478"); // hex val of 'block_tx'
pub const BLOCK_RECEIPT_LABEL: Felt252 = Felt252::from_hex_unchecked("0x626c6f636b5f72656365697074"); // hex val of 'block_receipt'

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
        ETHEREUM_MAINNET_CHAIN_ID => env::var(RPC_URL_ETHEREUM_MAINNET).map_err(|_| KeyError::MissingEnvVar {
            var_name: RPC_URL_ETHEREUM_MAINNET,
            chain_id: ETHEREUM_MAINNET_CHAIN_ID,
        }),
        ETHEREUM_TESTNET_CHAIN_ID => env::var(RPC_URL_ETHEREUM_TESTNET).map_err(|_| KeyError::MissingEnvVar {
            var_name: RPC_URL_ETHEREUM_TESTNET,
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
        }),
        OPTIMISM_MAINNET_CHAIN_ID => env::var(RPC_URL_OPTIMISM_MAINNET).map_err(|_| KeyError::MissingEnvVar {
            var_name: RPC_URL_OPTIMISM_MAINNET,
            chain_id: OPTIMISM_MAINNET_CHAIN_ID,
        }),
        OPTIMISM_TESTNET_CHAIN_ID => env::var(RPC_URL_OPTIMISM_TESTNET).map_err(|_| KeyError::MissingEnvVar {
            var_name: RPC_URL_OPTIMISM_TESTNET,
            chain_id: OPTIMISM_TESTNET_CHAIN_ID,
        }),
        other => Err(KeyError::UnsupportedChainId { chain_id: other }),
    }
}
