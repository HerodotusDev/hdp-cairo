use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
#[serde_as]
pub struct MmrMeta {
    pub id: Bytes,
    pub size: u64,
    pub root: Bytes,
    pub peaks: Vec<Bytes>,
    pub chain_id: u128,
}

#[derive(thiserror::Error, Debug)]
pub enum MmrMetaError {
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
}
