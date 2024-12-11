use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct MmrMeta {
    pub id: u64,
    pub size: u64,
    #[serde_as(as = "starknet_core::serde::unsigned_field_element::UfeHex")]
    pub root: Felt252,
    pub chain_id: u64,
    #[serde_as(as = "Vec<starknet_core::serde::unsigned_field_element::UfeHex>")]
    pub peaks: Vec<Felt252>,
}
