use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct MPTProof {
    pub block_number: u64,
    #[serde_as(as = "starknet_core::serde::unsigned_field_element::UfeHex")]
    pub proof: Vec<Felt252>,
}
