use header::Header;
use serde::{Deserialize, Serialize};
use storage::Storage;

use super::header::HeaderMmrMeta;

pub mod header;
pub mod storage;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta<Header>>,
    pub storages: Vec<Storage>,
}

impl Proofs {
    #[allow(clippy::len_without_is_empty)]
    pub fn len(&self) -> usize {
        self.headers_with_mmr.len() + self.storages.len()
    }
}
