use serde::{Deserialize, Serialize};

mod header;
mod storage;

use header::Header;
use storage::GetProofOutput;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers: Vec<Header>,
    pub storages: Vec<GetProofOutput>,
}
