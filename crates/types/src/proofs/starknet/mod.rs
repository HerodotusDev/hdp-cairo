use serde::{Deserialize, Serialize};

mod storage;
mod header;

use storage::GetProofOutput;
use header::Header;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers: Vec<Header>,
    pub storages: Vec<GetProofOutput>,
}