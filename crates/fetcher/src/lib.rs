use alloy::hex::FromHexError;
use indexer::types::IndexerError;
use std::num::ParseIntError;
use thiserror::Error;

pub mod proof_keys;

#[derive(Error, Debug)]
pub enum FetcherError {
    #[error(transparent)]
    Args(#[from] clap::error::Error),
    #[error("Output Error: {0}")]
    Output(String),
    #[error(transparent)]
    IO(#[from] std::io::Error),
    #[error(transparent)]
    Indexer(#[from] IndexerError),
    #[error(transparent)]
    ParseIntError(#[from] ParseIntError),
    #[error(transparent)]
    FromHexError(#[from] FromHexError),
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
    #[error("Internal Error: {0}")]
    InternalError(String),
}
