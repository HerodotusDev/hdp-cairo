use thiserror::Error;

pub mod accumulators;

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
}
