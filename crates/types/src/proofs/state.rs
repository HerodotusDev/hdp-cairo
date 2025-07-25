use bitvec::vec::BitVec;
use pathfinder_common::trie::TrieNode;
use serde::{Deserialize, Serialize};
use starknet_types_core::felt::Felt;

pub type StateProofs = Vec<StateProof>;

impl StateProof {
    pub fn action(&self) -> u128 {
        match self {
            StateProof::Inclusion(_) => 0,
            StateProof::Update(_) => 1,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum StateProof {
    Inclusion(Vec<TrieNodeSerde>),
    Update((Vec<TrieNodeSerde>, Vec<TrieNodeSerde>)),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum TrieNodeSerde {
    Binary { left: Felt, right: Felt },
    Edge { child: Felt, path: Vec<u8> },
}

impl From<TrieNode> for TrieNodeSerde {
    fn from(value: TrieNode) -> Self {
        match value {
            TrieNode::Binary { left, right } => Self::Binary {
                left: Felt::from_bytes_be(left.as_be_bytes()),
                right: Felt::from_bytes_be(right.as_be_bytes()),
            },
            TrieNode::Edge { child, path } => Self::Edge {
                child: Felt::from_bytes_be(child.as_be_bytes()),
                path: path.into_vec(),
            },
        }
    }
}

impl From<TrieNodeSerde> for TrieNode {
    fn from(value: TrieNodeSerde) -> Self {
        match value {
            TrieNodeSerde::Binary { left, right } => Self::Binary {
                left: left.to_bytes_be().into(),
                right: right.to_bytes_be().into(),
            },
            TrieNodeSerde::Edge { child, path } => Self::Edge {
                child: child.to_bytes_be().into(),
                path: BitVec::from_slice(&path),
            },
        }
    }
}
