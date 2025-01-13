use serde::{Deserialize, Serialize};
use crate::proofs::header::HeaderProof;
use starknet_types_core::felt::Felt;


#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
pub struct Header {
    pub fields: Vec<Felt>,
    pub proof: HeaderProof,
}