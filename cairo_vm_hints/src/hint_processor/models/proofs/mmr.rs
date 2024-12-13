use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct MmrMeta {
    pub id: u64,
    pub size: u64,
    pub root: Bytes,
    pub chain_id: u64,
    pub peaks: Vec<Bytes>,
}
