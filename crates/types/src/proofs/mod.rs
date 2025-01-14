pub mod evm;
pub mod header;
pub mod mmr;
pub mod mpt;
pub mod starknet;

use header::Header;
use mmr::MmrMeta;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default, Hash)]
pub struct HeaderMmrMeta {
    pub headers: Vec<Header>,
    pub mmr_meta: MmrMeta,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub evm: evm::Proofs,
    pub starknet: starknet::Proofs,
}
