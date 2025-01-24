use super::mmr::MmrMeta;
use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default, Hash)]
pub struct HeaderMmrMeta<T> {
    pub headers: Vec<T>,
    pub mmr_meta: MmrMeta,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
#[serde_as]
pub struct HeaderProof {
    pub leaf_idx: u64,
    pub mmr_path: Vec<Bytes>,
}
