use bitvec::{order::Msb0, vec::BitVec};
use pathfinder_common::trie::TrieNode;
use pathfinder_crypto::Felt;
use primitive_types::U256;
use serde::{Deserialize, Serialize};

use super::leaf::TrieLeaf;

#[derive(Debug, Serialize, Deserialize)]
pub struct VerificationCallData {
    path: Felt,
    nodes: Vec<[U256; 3]>,
    leaf: Felt,
    root: Felt,
}

impl VerificationCallData {
    // Constant matching IS_EDGE_NODE_FLAG in Solidity (1 << 255)
    // U256 uses little-endian u64 limbs. 1 << 255 sets the MSB of the highest limb.
    const IS_EDGE_NODE_FLAG_U256: U256 = U256([0, 0, 0, 1u64 << 63]);

    /// Converts a BitSlice (using Msb0 order) to a U256 (big-endian).
    /// The bits are right-aligned (padded with leading zeros) in the resulting U256.
    fn bits_to_u256(bits: &BitVec<u8, Msb0>) -> U256 {
        let felt = Felt::from_bits(bits)
            .expect("Failed to convert bits to Felt; check bit length compatibility.");

        // Convert the Felt to its big-endian byte representation ([u8; 32]).
        let felt_bytes = felt.to_be_bytes();

        // Create the U256 directly from the big-endian bytes provided by Felt.
        U256::from_big_endian(&felt_bytes)
    }

    pub fn from_proof(proof: &[(TrieNode, Felt)], leaf: &TrieLeaf, root: Felt) -> Self {
        let mut packed_nodes = Vec::with_capacity(proof.len());
        for (node, _hash) in proof {
            let packed_node = match node {
                TrieNode::Binary { left, right } => [
                    U256::from_big_endian(&left.to_be_bytes()),
                    U256::from_big_endian(&right.to_be_bytes()),
                    U256::from(0),
                ],
                TrieNode::Edge { child, path } => {
                    let path_len = path.len();

                    [
                        U256::from_big_endian(&child.to_be_bytes()),
                        VerificationCallData::bits_to_u256(path),
                        VerificationCallData::IS_EDGE_NODE_FLAG_U256 | U256::from(path_len),
                    ]
                }
            };
            packed_nodes.push(packed_node);
        }

        VerificationCallData {
            path: Felt::from_bits(&leaf.get_path()).unwrap(),
            nodes: packed_nodes,
            leaf: leaf.commitment(),
            root,
        }
    }
}
