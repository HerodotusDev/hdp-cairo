use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
#[serde_as]
pub struct HeaderProof {
    pub leaf_idx: u64,
    pub mmr_path: Vec<Bytes>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Header {
    pub rlp: Bytes,
    pub proof: HeaderProof,
}

// impl TryFrom<MMRProof> for Header {
//     fn try_from(value: MMRProof) -> Result<Self, Self::Error> {
//         Self {
//             rlp: value.block_header..
//         }
//     }
// }
