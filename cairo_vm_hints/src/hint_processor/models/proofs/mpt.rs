use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct MPTProof {
    pub block_number: u64,
    pub proof: Bytes,
}
