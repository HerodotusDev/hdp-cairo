use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};

use crate::proofs::header::HeaderProof;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
pub struct Header {
    pub fields: Vec<Felt252>,
    pub proof: HeaderProof,
}
