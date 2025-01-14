use alloy::primitives::Bytes;
use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
#[serde_as]
pub struct HeaderProof {
    pub leaf_idx: u64,
    pub mmr_path: Vec<Felt252>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
pub struct Header {
    pub payload: HeaderPayload,
    pub proof: HeaderProof,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde(untagged)]
pub enum HeaderPayload {
    Evm(Bytes),
    Starknet(Vec<Felt252>),
}

impl Default for HeaderPayload {
    fn default() -> Self {
        Self::Evm(Bytes::default())
    }
}
