use alloy::primitives::{BlockNumber, ChainId};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;
use std::collections::HashMap;
use thiserror::Error;

/// Enum for available hashing functions
#[derive(Debug, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum HashingFunction {
    Keccak,
    Poseidon,
    Pedersen,
}

/// Enum for available contract types
#[derive(Debug, Serialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum ContractType {
    Aggregator,
    Accumulator,
    Remapper,
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
}

/// Query parameters for the indexer
#[derive(Debug, Serialize)]
pub struct IndexerQuery {
    pub deployed_on_chain: ChainId,
    pub accumulates_chain: ChainId,
    pub hashing_function: HashingFunction,
    pub contract_type: ContractType,
    pub from_block_number_inclusive: BlockNumber,
    pub to_block_number_inclusive: BlockNumber,
    pub is_meta_included: bool,
    pub is_whole_tree: bool,
    pub is_rlp_included: bool,
    pub is_pure_rlp: bool,
}

impl IndexerQuery {
    pub fn new(chain_id: ChainId, from_block: BlockNumber, to_block: BlockNumber) -> Self {
        Self {
            deployed_on_chain: chain_id,
            accumulates_chain: chain_id,
            hashing_function: HashingFunction::Poseidon,
            contract_type: ContractType::Aggregator,
            from_block_number_inclusive: from_block,
            to_block_number_inclusive: to_block,
            is_meta_included: true,
            is_whole_tree: true,
            is_rlp_included: true,
            is_pure_rlp: true,
        }
    }
}

/// MMR metadata and proof returned from indexer
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MMRResponse {
    pub data: Vec<MMRData>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct MMRData {
    pub meta: MMRMetadata,
    pub proofs: Vec<MMRProof>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct MMRMetadata {
    pub mmr_id: String,
    pub mmr_peaks: Vec<String>,
    pub mmr_root: String,
    pub mmr_size: u64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde_as]
pub struct MMRProof {
    pub block_number: u64,
    pub element_hash: String,
    pub element_index: u64,
    pub block_header: BlockHeader,
    pub siblings_hashes: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum BlockHeader {
    RlpString(String),
    RlpLittleEndian8ByteChunks(Vec<String>),
    Fields(Vec<String>),
}

#[derive(Debug)]
pub struct IndexerHeadersProofResponse {
    pub mmr_meta: MMRMetadata,
    pub headers: HashMap<BlockNumber, MMRProof>,
}

impl IndexerHeadersProofResponse {
    pub fn new(mmr_data: MMRData) -> Self {
        let mmr_meta = mmr_data.meta;
        let headers = mmr_data.proofs.into_iter().map(|block| (block.block_number, block)).collect();
        Self { mmr_meta, headers }
    }
}
