use crate::proofs::mpt::MPTProof;
use alloy::primitives::U256;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Transaction {
    pub key: U256,
    pub proof: MPTProof,
}

impl Transaction {
    pub fn new(key: U256, proof: MPTProof) -> Self {
        Self { key, proof }
    }
}
