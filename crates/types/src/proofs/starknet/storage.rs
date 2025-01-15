// Diclaimers:
// Currently, there is no good way of importing this type from an external crate. We have found the following implementations:
// - https://github.com/keep-starknet-strange/snos/tree/main/crates/rpc-client/src/pathfinder
// - https://github.com/eqlabs/pathfinder/blob/main/crates/rpc/src/pathfinder/methods/get_proof.rs
// Both fo these implementations essentially force us to follow the cairo-vm versions that are used, which is a bad idea for us to do.
// We should aim for finding an implementation that we can simply update instead of manageing it ourself.
// This is a temporary solution that we should aim to replace.

use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};
use serde_with::skip_serializing_none;
use starknet_types_core::hash::StarkHash;

/// Codebase is from <https://github.com/eqlabs/pathfinder/tree/ae81d84b7c4157891069bd02ef810a29b60a94e3>
/// Holds the membership/non-membership of a contract and its associated
/// contract contract if the contract exists.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
#[skip_serializing_none]
pub struct GetProofOutput {
    /// The global state commitment for Starknet 0.11.0 blocks onwards, if
    /// absent the hash of the first node in the
    /// [contract_proof](GetProofOutput#contract_proof) is the global state
    /// commitment.
    pub state_commitment: Option<Felt252>,
    /// Required to verify that the hash of the class commitment and the root of
    /// the [contract_proof](GetProofOutput::contract_proof) matches the
    /// [state_commitment](Self#state_commitment). Present only for Starknet
    /// blocks 0.11.0 onwards.
    pub class_commitment: Option<Felt252>,

    /// Membership / Non-membership proof for the queried contract
    pub contract_proof: Vec<TrieNode>,

    /// Additional contract data if it exists.
    pub contract_data: Option<ContractData>,
}

/// A node in a Starknet patricia-merkle trie.
///
/// See pathfinders merkle-tree crate for more information.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub enum TrieNode {
    #[serde(rename = "binary")]
    Binary { left: Felt252, right: Felt252 },
    #[serde(rename = "edge")]
    Edge { child: Felt252, path: Path },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Path {
    len: u64,
    value: String,
}

impl TrieNode {
    pub fn hash<H: StarkHash>(&self) -> Felt252 {
        match self {
            TrieNode::Binary { left, right } => H::hash(left, right),
            TrieNode::Edge { child, path } => {
                let bytes: [u8; 32] = path.value.as_bytes().try_into().unwrap();
                let mut length = [0; 32];
                // Safe as len() is guaranteed to be <= 251
                length[31] = bytes.len() as u8;

                let length = Felt252::from_bytes_be(&length);
                let path = Felt252::from_bytes_be(&bytes);
                H::hash(child, &path) + length
            }
        }
    }
}

/// Holds the data and proofs for a specific contract.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct ContractData {
    /// Required to verify the contract state hash to contract root calculation.
    class_hash: Felt252,
    /// Required to verify the contract state hash to contract root calculation.
    nonce: Felt252,

    /// Root of the Contract state tree
    root: Felt252,

    /// This is currently just a constant = 0, however it might change in the
    /// future.
    contract_state_hash_version: Felt252,

    /// The proofs associated with the queried storage values
    pub storage_proofs: Vec<Vec<TrieNode>>,
}
