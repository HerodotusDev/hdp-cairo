use pathfinder_rpc::GetProofOutput;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub storages: Vec<GetProofOutput>,
}
