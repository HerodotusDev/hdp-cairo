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

// impl MmrMeta {
//     pub fn from_indexer(data: indexer::types::MMRMetadata) -> Result<Self, MmrMetaError> {
//         Ok(Self {
//             id: u64::from_str_radix(&data.mmr_id, 16).unwrap(),
//             size: (),
//             root: (),
//             chain_id: (),
//             peaks: (),
//         })
//     }
// }

#[derive(thiserror::Error, Debug)]
pub enum MmrMetaError {
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
}
