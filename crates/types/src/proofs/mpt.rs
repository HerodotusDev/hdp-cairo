use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct MPTProof {
    pub block_number: u64,
    pub proof: Vec<Bytes>,
}

impl MPTProof {
    pub fn new(block_number: u64, proof: Vec<Bytes>) -> Self {
        Self { block_number, proof }
    }
}
