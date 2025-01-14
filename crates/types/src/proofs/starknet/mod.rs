use super::header::HeaderMmrMeta;
use header::Header;
use serde::{Deserialize, Serialize};
use storage::GetProofOutput;

pub mod header;
pub mod storage;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers: Vec<HeaderMmrMeta<Header>>,
    pub storages: Vec<GetProofOutput>,
}
