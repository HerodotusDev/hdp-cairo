use bitvec::{order::Msb0, vec::BitVec};
pub use pathfinder_common::hash::keccak_hash as keccak_hash_truncated;
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub struct TrieLeaf {
    pub key: Felt,
    pub data: LeafData,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LeafUpdate {
    pub key: Felt,
    pub old_data: LeafData,
    pub new_data: LeafData,
}

#[derive(Debug, Copy, Clone, Serialize, Deserialize)]
pub struct LeafData {
    pub value: Felt,
}

impl LeafData {
    pub fn new(value: Felt) -> Self {
        Self { value }
    }
}

impl LeafUpdate {
    pub fn get_path(&self) -> BitVec<u8, Msb0> {
        self.key.view_bits().to_bitvec()
    }

    pub fn as_old_leaf(&self) -> TrieLeaf {
        TrieLeaf {
            key: self.key,
            data: self.old_data,
        }
    }

    pub fn as_new_leaf(&self) -> TrieLeaf {
        TrieLeaf {
            key: self.key,
            data: self.new_data,
        }
    }
}

impl TrieLeaf {
    pub fn new(key: Felt, value: Felt) -> Self {
        let data = LeafData::new(value);
        Self { key, data }
    }

    pub fn empty(key: Felt) -> Self {
        let data = LeafData::new(Felt::ZERO);

        Self { key, data }
    }

    pub fn set_value(&self, value: Felt) -> LeafUpdate {
        let new_data = LeafData::new(value);
        LeafUpdate {
            key: self.key,
            old_data: self.data,
            new_data,
        }
    }

    pub fn commitment(&self) -> Felt {
        self.data.value
    }

    pub fn get_key(&self) -> Felt {
        self.key
    }

    pub fn get_path(&self) -> BitVec<u8, Msb0> {
        self.key.view_bits().to_bitvec()
    }

    pub fn compute_path(key: Felt) -> BitVec<u8, Msb0> {
        key.view_bits().to_bitvec()
    }

    pub fn is_empty(&self) -> bool {
        self.data.value == Felt::ZERO
    }
}
