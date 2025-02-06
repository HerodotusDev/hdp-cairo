use alloy::primitives::U256;
use serde::{Deserialize, Serialize};

use crate::proofs::mpt::MPTProof;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Receipt {
    pub key: U256,
    pub proof: MPTProof,
}

impl Receipt {
    pub fn new(key: U256, proof: MPTProof) -> Self {
        Self { key, proof }
    }
}
