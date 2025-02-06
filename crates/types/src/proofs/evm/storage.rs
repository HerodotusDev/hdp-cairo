use alloy::primitives::{keccak256, Address, StorageKey, B256};
use serde::{Deserialize, Serialize};

use crate::proofs::mpt::MPTProof;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Storage {
    pub address: Address,
    pub slot: B256,
    pub storage_key: StorageKey,
    pub proofs: Vec<MPTProof>,
}

impl Storage {
    pub fn new(address: Address, slot: B256, proofs: Vec<MPTProof>) -> Self {
        // TODO: actually this is storage leaf. slot == storage key
        let storage_trie_leaf = keccak256(slot);
        Storage {
            address,
            slot,
            storage_key: storage_trie_leaf,
            proofs,
        }
    }
}
