use super::header::HeaderMmrMeta;
use header::Header;
use serde::{Deserialize, Serialize};
use storage::Storage;

pub mod header;
pub mod storage;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta<Header>>,
    pub storages: Vec<Storage>,
}
