use super::mpt::MPTProof;
use alloy::primitives::U256;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Transaction {
    pub key: U256,
    pub proofs: Vec<MPTProof>,
}

impl Transaction {
    pub fn new(key: U256, proofs: Vec<MPTProof>) -> Self {
        Self { key, proofs }
    }
}
