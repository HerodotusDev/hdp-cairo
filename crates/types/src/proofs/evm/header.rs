use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};

use crate::proofs::header::HeaderProof;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
pub struct Header {
    pub rlp: Bytes,
    pub proof: HeaderProof,
}
