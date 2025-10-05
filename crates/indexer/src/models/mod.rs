use serde::{Deserialize, Serialize};
use thiserror::Error;
pub use types::HashingFunction;

pub mod accumulators;
pub mod blocks;
pub mod ranges;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum BlockHeader {
    RlpString(String),
    RlpLittleEndian8ByteChunks(Vec<String>),
    Fields(Vec<String>),
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
