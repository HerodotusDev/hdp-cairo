
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use types::keys;
use strum_macros::FromRepr;


pub mod header;
pub mod storage;

#[derive(FromRepr)]
pub enum CallHandlerId {
    Header = 0,
    Storage = 1,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Clone)]
#[serde(rename_all = "lowercase")]
pub enum DryRunKey {
    Header(keys::starknet::header::Key),
    Storage(keys::starknet::storage::Key),
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandler {
    pub key_set: HashSet<DryRunKey>,
}
