pub mod leaf;
pub mod proof;

use std::vec::IntoIter;

use bitvec::{order::Msb0, vec::BitVec};
use cairo_vm::Felt252;
use pathfinder_common::trie::TrieNode;
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

use crate::{
    cairo::{FELT_0, FELT_1},
    proofs::injected_state::leaf::TrieLeaf,
};

pub type StateProofs = Vec<StateProof>;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum StateProof {
    Read(StateProofRead),
    Write(StateProofWrite),
}

impl StateProof {
    pub fn get_type(&self) -> Felt252 {
        match self {
            Self::Read(_) => FELT_0,
            Self::Write(_) => FELT_1,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct StateProofRead {
    pub trie_label: Felt,
    pub trie_root: Felt,
    pub state_proof: Vec<TrieNodeSerde>,
    pub leaf: TrieLeaf,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct StateProofWrite {
    pub trie_label: Felt,
    pub trie_root_prev: Felt,
    pub state_proof_prev: Vec<TrieNodeSerde>,
    pub leaf_prev: TrieLeaf,
    pub trie_root_post: Felt,
    pub state_proof_post: Vec<TrieNodeSerde>,
    pub leaf_post: TrieLeaf,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum TrieNodeSerde {
    Binary { left: Felt, right: Felt },
    // Stores both the raw bytes which back the bit-vector *and* the
    // original bit-length so it can be reconstructed losslessly.
    Edge { child: Felt, path: Vec<u8>, bit_len: usize },
}

impl From<TrieNode> for TrieNodeSerde {
    fn from(value: TrieNode) -> Self {
        match value {
            TrieNode::Binary { left, right } => Self::Binary {
                left: left.to_be_bytes().into(),
                right: right.to_be_bytes().into(),
            },
            TrieNode::Edge { child, path } => {
                // Preserve the exact bit length so the path can be faithfully
                // reconstructed later. Converting a `BitVec` into the
                // underlying `Vec<u8>` alone loses the information about how
                // many *bits* of the last byte are actually used.

                let bit_len = path.len();
                let vec_path = path.into_vec();

                Self::Edge {
                    child: child.to_be_bytes().into(),
                    path: vec_path,
                    bit_len,
                }
            }
        }
    }
}

impl From<TrieNodeSerde> for TrieNode {
    fn from(value: TrieNodeSerde) -> Self {
        match value {
            TrieNodeSerde::Binary { left, right } => Self::Binary {
                left: left.to_be_bytes().into(),
                right: right.to_be_bytes().into(),
            },
            TrieNodeSerde::Edge { child, path, bit_len } => Self::Edge {
                child: child.to_be_bytes().into(),
                path: {
                    let mut bitvec = BitVec::<u8, Msb0>::from_slice(&path);
                    // Restore the original bit-length (max 251 for Starknet)
                    bitvec.truncate(bit_len.min(251));
                    bitvec
                },
            },
        }
    }
}

pub struct CairoTrieNodeSerde(pub TrieNodeSerde);

impl IntoIterator for CairoTrieNodeSerde {
    type Item = Felt252;
    type IntoIter = IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        match self.0 {
            TrieNodeSerde::Binary { left, right } => vec![
                FELT_0,
                Felt252::from_hex(&left.to_hex_str()).unwrap(),
                Felt252::from_hex(&right.to_hex_str()).unwrap(),
                FELT_0,
            ]
            .into_iter(),
            TrieNodeSerde::Edge { child, path, bit_len } => {
                let mut bitvec = BitVec::<u8, Msb0>::from_slice(&path);
                bitvec.truncate(bit_len.min(251));
                let path = Felt::from_bits(&bitvec).unwrap();
                vec![
                    FELT_1,
                    Felt252::from_bytes_be(&child.to_be_bytes()),
                    Felt252::from_hex(&path.to_hex_str()).unwrap(),
                    Felt252::from(bit_len as u64),
                ]
                .into_iter()
            }
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Action {
    Read(ActionRead),
    Write(ActionWrite),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionRead {
    pub trie_label: Felt,
    pub trie_root: Felt,
    pub key: Felt,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionWrite {
    pub trie_label: Felt,
    // Root hash before write operation is applied
    pub trie_root: Felt,
    pub key: Felt,
    pub value: Felt,
}
