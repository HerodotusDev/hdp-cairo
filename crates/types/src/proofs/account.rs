use super::mpt::MPTProof;
use alloy::primitives::{keccak256, Address, B256};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Account {
    pub address: Address,
    pub account_key: B256,
    pub proofs: Vec<MPTProof>,
}

impl Account {
    pub fn new(address: Address, proofs: Vec<MPTProof>) -> Self {
        // TODO: actually this is account trie leaf to be more accurate
        let account_trie_leaf = keccak256(address);
        Account {
            address,
            account_key: account_trie_leaf,
            proofs,
        }
    }
}
