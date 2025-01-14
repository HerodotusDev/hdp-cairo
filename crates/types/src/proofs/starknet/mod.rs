use super::HeaderMmrMeta;
use serde::{Deserialize, Serialize};

mod storage;
use storage::GetProofOutput;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta>,
    pub storages: Vec<GetProofOutput>,
}