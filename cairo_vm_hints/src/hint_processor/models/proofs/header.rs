use alloy::primitives::Bytes;
use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct HeaderProof {
    pub leaf_idx: u64,
    #[serde_as(as = "Vec<starknet_core::serde::unsigned_field_element::UfeHex>")]
    pub mmr_path: Vec<Felt252>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Header {
    pub rlp: Bytes,
    pub proof: HeaderProof,
}
