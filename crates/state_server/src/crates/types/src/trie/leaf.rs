use std::collections::HashMap;

use bitvec::{order::Msb0, vec::BitVec};
pub use pathfinder_common::hash::keccak_hash as keccak_hash_truncated;
use pathfinder_common::{hash::FeltHash, trie::TrieNode};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrieLeaf {
    pub address: Felt,
    pub data: LeafData,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LeafUpdate {
    pub address: Felt,
    pub old_data: LeafData,
    pub new_data: LeafData,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LeafData {
    pub has_delegated: bool,
    pub voting_power: Felt,
    pub commitment: Felt,
}

impl LeafData {
    pub fn new(has_delegated: bool, voting_power: Felt) -> Self {
        Self {
            has_delegated,
            voting_power,
            commitment: keccak_hash_truncated(Felt::from(has_delegated as u64), voting_power),
        }
    }
}

impl LeafUpdate {
    pub fn get_path(&self) -> BitVec<u8, Msb0> {
        self.address.view_bits().to_bitvec()
    }

    pub fn as_old_leaf(&self) -> TrieLeaf {
        TrieLeaf {
            address: self.address,
            data: self.old_data.clone(),
        }
    }

    pub fn as_new_leaf(&self) -> TrieLeaf {
        TrieLeaf {
            address: self.address,
            data: self.new_data.clone(),
        }
    }
}
impl TrieLeaf {
    pub fn new(address: Felt, has_delegated: bool, voting_power: Felt) -> Self {
        let data = LeafData::new(has_delegated, voting_power);
        Self { address, data }
    }

    pub fn empty(address: Felt) -> Self {
        let data = LeafData {
            has_delegated: false,
            voting_power: Felt::ZERO,
            commitment: Felt::ZERO,
        };

        Self { address, data }
    }

    pub fn set_has_delegated(&self) -> LeafUpdate {
        let new_data = LeafData::new(true, self.data.voting_power);
        LeafUpdate {
            address: self.address,
            old_data: self.data.clone(),
            new_data,
        }
    }

    pub fn increase_voting_power(&self, amount: Felt) -> LeafUpdate {
        let new_data = LeafData::new(self.data.has_delegated, self.data.voting_power + amount);

        LeafUpdate {
            address: self.address,
            old_data: self.data.clone(),
            new_data,
        }
    }

    pub fn commitment(&self) -> Felt {
        self.data.commitment
    }

    pub fn get_key(&self) -> Felt {
        self.address
    }

    pub fn get_path(&self) -> BitVec<u8, Msb0> {
        self.address.view_bits().to_bitvec()
    }

    #[allow(dead_code)]
    pub fn compute_path(address: Felt) -> BitVec<u8, Msb0> {
        address.view_bits().to_bitvec()
    }
}

pub fn generate_preimage<H: FeltHash>(
    preimage: &mut HashMap<String, Vec<String>>,
    proof: Vec<(TrieNode, Felt)>,
) {
    proof.iter().for_each(|(node, _)| {
        let hash = node.hash::<H>();
        match node {
            TrieNode::Binary { left, right } => {
                let _ = preimage.insert(
                    hex::encode(hash.to_be_bytes()),
                    vec![
                        hex::encode(left.to_be_bytes()),
                        hex::encode(right.to_be_bytes()),
                    ],
                );
            }
            TrieNode::Edge { child, path } => {
                let _ = preimage.insert(
                    hex::encode(hash.to_be_bytes()),
                    vec![
                        hex::encode(path.len().to_be_bytes()),
                        hex::encode(Felt::from_bits(path).unwrap().to_be_bytes()),
                        hex::encode(child.to_be_bytes()),
                    ],
                );
            }
        }
    });
}
