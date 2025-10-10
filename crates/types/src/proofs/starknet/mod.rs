use header::Header;
use serde::{Deserialize, Serialize};
use storage::Storage;

use super::header::HeaderMmrMeta;

pub mod header;
pub mod storage;

#[derive(Clone, Debug, Serialize, Deserialize, Default, PartialEq, Eq, Hash)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta<Header>>,
    pub storages: Vec<Storage>,
}

impl Proofs {
    pub fn len(&self) -> usize {
        self.headers_with_mmr.len() + self.storages.len()
    }

    pub fn is_empty(&self) -> bool {
        self.headers_with_mmr.is_empty() && self.storages.is_empty()
    }
}
