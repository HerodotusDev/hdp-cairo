use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};
use types::{BlockNumber, ChainId};

use super::{BlockHeader, HashingFunction};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum Sorting {
    Ascending,
    Descending,
}

/// Query parameters for the indexer
#[derive(Debug, Serialize)]
pub struct IndexerQuery {
    pub chain_id: ChainId,
    pub hashing_function: HashingFunction,
    pub from_block_number_inclusive: BlockNumber,
    pub to_block_number_inclusive: BlockNumber,
    pub sort: Sorting,
}

impl IndexerQuery {
    pub fn new(chain_id: ChainId, from_block: BlockNumber, to_block: BlockNumber) -> Self {
        Self {
            chain_id,
            hashing_function: HashingFunction::Poseidon,
            from_block_number_inclusive: from_block,
            to_block_number_inclusive: to_block,
            sort: Sorting::Ascending,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Block {
    pub block_number: BlockNumber,
    pub block_header: BlockHeader,
    pub block_hash: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BlocksResponse {
    pub data: Vec<Block>,
}

#[derive(Debug)]
pub struct IndexerBlockResponse {
    pub fields: Vec<Felt252>,
}

impl IndexerBlockResponse {
    pub fn new(fields: Vec<Felt252>) -> Self {
        Self { fields }
    }
}
