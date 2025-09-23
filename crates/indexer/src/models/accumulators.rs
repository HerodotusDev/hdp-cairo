use std::collections::HashMap;

use alloy::primitives::BlockNumber;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use super::{BlockHeader, HashingFunction};

/// Enum for available contract types
#[derive(Debug, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ContractType {
    /// Satellite contract type is used for all EVM contracts
    Satellite,
    /// Mmr contract type is used only for Starknet HeadersStore contracts
    Mmr,
    /// Remapper contract type is used only for Starknet TimestampRemappers contracts
    Remapper,
}

/// Query parameters for the indexer
#[derive(Debug, Serialize)]
pub struct IndexerQuery {
    pub deployed_on_chain: u128,
    pub accumulates_chain: u128,
    pub hashing_function: HashingFunction,
    pub contract_type: ContractType,
    pub from_block_number_inclusive: BlockNumber,
    pub to_block_number_inclusive: BlockNumber,
    pub is_meta_included: bool,
    pub is_whole_tree: bool,
    pub is_rlp_included: bool,
    pub is_pure_rlp: bool,
    pub prefer_native_block_header: bool,
}

impl IndexerQuery {
    pub fn new(deployed_on_chain_id: u128, accumulates_chain_id: u128, from_block: BlockNumber, to_block: BlockNumber) -> Self {
        Self {
            deployed_on_chain: deployed_on_chain_id,
            accumulates_chain: accumulates_chain_id,
            hashing_function: HashingFunction::Poseidon,
            contract_type: ContractType::Mmr,
            from_block_number_inclusive: from_block,
            to_block_number_inclusive: to_block,
            is_meta_included: true,
            is_whole_tree: true,
            is_rlp_included: true,
            is_pure_rlp: true,
            prefer_native_block_header: false,
        }
    }

    pub fn with_hashing_function(mut self, hashing: HashingFunction) -> Self {
        self.hashing_function = hashing;
        self
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
    pub block_header: BlockHeader,
    pub block_number: u64,
    pub element_hash: String,
    pub element_index: u64,
    pub siblings_hashes: Vec<String>,
}

#[derive(Debug)]
pub struct IndexerProofResponse {
    pub mmr_meta: MMRMetadata,
    pub headers: HashMap<BlockNumber, MMRProof>,
}

impl IndexerProofResponse {
    pub fn new(mmr_data: MMRData) -> Self {
        let mmr_meta = mmr_data.meta;
        let headers = mmr_data.proofs.into_iter().map(|block| (block.block_number, block)).collect();
        Self { mmr_meta, headers }
    }
}
