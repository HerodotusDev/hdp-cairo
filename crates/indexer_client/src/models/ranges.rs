use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct FunctionsRanges {
    #[serde(default)]
    pub keccak: Vec<[u64; 2]>,
    #[serde(default)]
    pub poseidon: Vec<[u64; 2]>,
}

pub type RangesResponse = HashMap<String, HashMap<String, FunctionsRanges>>;