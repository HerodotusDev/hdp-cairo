use core::fmt;

use cairo_vm::Felt252;
use pathfinder_common::trie::TrieNode;
use pathfinder_crypto::Felt;
use serde::{
    de::{self, MapAccess, Visitor},
    Deserialize, Deserializer, Serialize,
};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Storage {
    pub block_number: u64,
    pub contract_address: Felt252,
    pub storage_addresses: Vec<Felt252>,
    pub proof: Felt252,
}

impl Storage {
    pub fn new(block_number: u64, contract_address: Felt252, storage_addresses: Vec<Felt252>, proof: Felt252) -> Self {
        Self {
            block_number,
            contract_address,
            storage_addresses,
            proof,
        }
    }
}

#[derive(Debug, PartialEq, Eq, Hash)]
struct ProofNode(TrieNode);

struct ProofNodeVisitor;

impl<'de> Visitor<'de> for ProofNodeVisitor {
    type Value = ProofNode;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a map representing either a Binary or an Edge node")
    }

    fn visit_map<M>(self, mut map: M) -> Result<Self::Value, M::Error>
    where
        M: MapAccess<'de>,
    {
        // Use Options to hold potentially present fields.
        let mut left: Option<Felt> = None;
        let mut right: Option<Felt> = None;
        let mut path: Option<Felt> = None;
        let mut length: Option<usize> = None;
        let mut child: Option<Felt> = None;

        // Iterate over the keys in the map.
        while let Some(key) = map.next_key::<String>()? {
            match key.as_str() {
                "left" => {
                    if left.is_some() {
                        return Err(de::Error::duplicate_field("left"));
                    }
                    left = Some(map.next_value()?);
                }
                "right" => {
                    if right.is_some() {
                        return Err(de::Error::duplicate_field("right"));
                    }
                    right = Some(map.next_value()?);
                }
                "path" => {
                    if path.is_some() {
                        return Err(de::Error::duplicate_field("path"));
                    }
                    path = Some(map.next_value()?);
                }
                "length" => {
                    if length.is_some() {
                        return Err(de::Error::duplicate_field("length"));
                    }
                    length = Some(map.next_value()?);
                }
                "child" => {
                    if child.is_some() {
                        return Err(de::Error::duplicate_field("child"));
                    }
                    child = Some(map.next_value()?);
                }
                _ => {
                    // Ignore unknown fields to be more robust.
                    let _ = map.next_value::<de::IgnoredAny>()?;
                }
            }
        }

        // --- Logic to decide which variant to build ---

        // Case 1: We have 'left' and 'right', so it must be a Binary node.
        if let (Some(left), Some(right)) = (left, right) {
            // Ensure no Edge node fields are also present.
            if path.is_some() || length.is_some() || child.is_some() {
                return Err(de::Error::custom("found both Binary and Edge fields in the same node"));
            }
            Ok(ProofNode(TrieNode::Binary { left, right }))

        // Case 2: We have 'path', 'length', and 'child', so it must be an Edge node.
        } else if let (Some(path_felt), Some(len), Some(child)) = (path, length, child) {
            // Ensure no Binary node fields are also present.
            if left.is_some() || right.is_some() {
                return Err(de::Error::custom("found both Binary and Edge fields in the same node"));
            }

            // Reconstruct the BitVec from the Felt and length.
            // `to_bits()` might return a fixed-size bit vector (e.g., 251 bits).
            // We truncate it to the original length saved during serialization.
            let path_bits = path_felt.view_bits();

            Ok(ProofNode(TrieNode::Edge {
                child,
                path: path_bits[..len].to_bitvec(),
            }))

        // Case 3: The combination of fields is invalid.
        } else {
            Err(de::Error::custom(
                "missing fields: expected either ('left', 'right') or ('path', 'length', 'child')",
            ))
        }
    }
}

impl<'de> Deserialize<'de> for ProofNode {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        // Define all possible field names for better error messages.
        const FIELDS: &[&str] = &["left", "right", "path", "length", "child"];
        deserializer.deserialize_struct("ProofNode", FIELDS, ProofNodeVisitor)
    }
}
