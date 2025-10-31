use std::{num::ParseIntError, ops::Deref};

use alloy::primitives::map::HashMap;
use serde::{Deserialize, Serialize};
use thiserror::Error;
use types::{
    HashingFunction, ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID,
    STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
};

pub mod accumulators;
pub mod blocks;
pub mod ranges;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum BlockHeader {
    RlpString(String),
    RlpLittleEndian8ByteChunks(Vec<String>),
    Fields(Vec<String>),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MMRHasherConfig(HashMap<u128, HashingFunction>);

impl Default for MMRHasherConfig {
    fn default() -> Self {
        Self(
            [
                (ETHEREUM_MAINNET_CHAIN_ID, HashingFunction::Poseidon),
                (ETHEREUM_TESTNET_CHAIN_ID, HashingFunction::Poseidon),
                (STARKNET_MAINNET_CHAIN_ID, HashingFunction::Poseidon),
                (STARKNET_TESTNET_CHAIN_ID, HashingFunction::Poseidon),
                (OPTIMISM_MAINNET_CHAIN_ID, HashingFunction::Poseidon),
                (OPTIMISM_TESTNET_CHAIN_ID, HashingFunction::Poseidon),
            ]
            .into_iter()
            .collect(),
        )
    }
}

impl Deref for MMRHasherConfig {
    type Target = HashMap<u128, HashingFunction>;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MMRDeploymentConfig(HashMap<u128, u128>);

impl Default for MMRDeploymentConfig {
    fn default() -> Self {
        Self(
            [
                (ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_MAINNET_CHAIN_ID),
                (ETHEREUM_TESTNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID),
                (STARKNET_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID),
                (STARKNET_TESTNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID),
                (OPTIMISM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID),
                (OPTIMISM_TESTNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID),
            ]
            .into_iter()
            .collect(),
        )
    }
}

impl Deref for MMRDeploymentConfig {
    type Target = HashMap<u128, u128>;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

/// Error from [`Indexer`]
#[derive(Error, Debug)]
pub enum IndexerError {
    /// The block range provided is invalid.
    #[error("Invalid block range")]
    InvalidBlockRange,

    /// Failed to send a request using [`reqwest`].
    #[error("Failed to send request")]
    ReqwestError(#[from] reqwest::Error),

    /// Failed to parse the response using [`serde_json`].
    #[error("Failed to parse response")]
    SerdeJsonError(#[from] serde_json::Error),

    /// Failed to parse Int.
    #[error("Failed to parse Int")]
    ParseIntError(#[from] ParseIntError),

    /// Validation error with a detailed message.
    #[error("Validation error: {0}")]
    ValidationError(String),

    /// Failed to get headers proof with a detailed message.
    #[error("Failed to get headers proof: {0}")]
    GetHeadersProofError(String),

    /// Failed to get blocks with a detailed message.
    #[error("Failed to get blocks: {0}")]
    GetBlocksProofError(String),

    /// Failed to get accumulated ranges with a detailed message.
    #[error("Failed to get accumulated ranges: {0}")]
    GetRangesError(String),
}
