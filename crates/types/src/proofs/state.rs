use std::vec::IntoIter;

use bitvec::{order::Msb0, vec::BitVec};
use cairo_vm::Felt252;
use pathfinder_common::trie::TrieNode;
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};
use state_server_types::trie::leaf::TrieLeaf;

use crate::cairo::{FELT_0, FELT_1};

pub type StateProofs = Vec<StateProofWrapper>; // should be wrapper

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct StateProofWrapper {
    pub trie_id: Felt,
    pub state_proof: StateProof,
    pub root_hash: Felt,
    pub leaf: TrieLeaf,
    pub post_proof_root_hash: Option<Felt>,
    pub post_proof_leaf: Option<TrieLeaf>,
}

impl Default for StateProofWrapper {
    fn default() -> Self {
        Self {
            trie_id: Felt::ZERO,
            state_proof: StateProof::NonInclusion(Vec::new()),
            root_hash: Felt::ZERO,
            leaf: TrieLeaf::new(Felt::ZERO, Felt::ZERO),
            post_proof_root_hash: None,
            post_proof_leaf: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum StateProof {
    Inclusion(Vec<TrieNodeSerde>),
    NonInclusion(Vec<TrieNodeSerde>),
    Update((Vec<TrieNodeSerde>, Vec<TrieNodeSerde>)),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum TrieNodeSerde {
    Binary { left: Felt, right: Felt },
    // Stores both the raw bytes which back the bit-vector *and* the
    // original bit-length so it can be reconstructed losslessly.
    Edge { child: Felt, path: Vec<u8>, bit_len: usize },
}

impl TrieNodeSerde {
    pub fn byte_len(&self) -> usize {
        match self {
            TrieNodeSerde::Binary { .. } => 64,                  // 2 Felts * 32 bytes each
            TrieNodeSerde::Edge { path, .. } => 32 + path.len(), // 1 Felt + path bytes
        }
    }
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
                let mut bytes = [0u8; 32];
                let len = path.len().min(32);
                bytes[..len].copy_from_slice(&path[..len]);
                vec![
                    FELT_1,
                    Felt252::from_hex(&child.to_hex_str()).unwrap(),
                    Felt252::from_bytes_be_slice(&bytes),
                    Felt252::from(bit_len as u64),
                ]
                .into_iter()
            }
        }
    }
}
