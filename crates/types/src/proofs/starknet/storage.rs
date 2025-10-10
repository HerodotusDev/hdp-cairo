use core::fmt;

use cairo_vm::Felt252;
use pathfinder_common::{trie::TrieNode, BlockHash, ClassHash, ContractNonce, ContractRoot};
use pathfinder_crypto::Felt;
use serde::{
    de::{self, MapAccess, Visitor},
    ser::SerializeStruct,
    Deserialize, Deserializer, Serialize, Serializer,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Storage {
    pub block_number: u64,
    pub contract_address: Felt252,
    pub storage_addresses: Vec<Felt252>,
    pub output: Output,
}

impl Storage {
    pub fn new(block_number: u64, contract_address: Felt252, storage_addresses: Vec<Felt252>, output: Output) -> Self {
        Self {
            block_number,
            contract_address,
            storage_addresses,
            output,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct Output {
    pub classes_proof: NodeHashToNodeMappings,
    pub contracts_proof: ContractsProof,
    pub contracts_storage_proofs: Vec<NodeHashToNodeMappings>,
    pub global_roots: GlobalRoots,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct GlobalRoots {
    pub contracts_tree_root: Felt,
    pub classes_tree_root: Felt,
    pub block_hash: BlockHash,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct ContractsProof {
    pub nodes: NodeHashToNodeMappings,
    pub contract_leaves_data: Vec<ContractLeafData>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct ContractLeafData {
    pub nonce: ContractNonce,
    pub class_hash: ClassHash,
    pub storage_root: ContractRoot,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct NodeHashToNodeMappings(pub Vec<NodeHashToNodeMapping>);

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct NodeHashToNodeMapping {
    pub node_hash: Felt,
    pub node: ProofNode,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ProofNode(pub TrieNode);

impl Serialize for ProofNode {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match &self.0 {
            TrieNode::Binary { left, right } => {
                let mut s = serializer.serialize_struct("ProofNode", 2)?;
                s.serialize_field("left", left)?;
                s.serialize_field("right", right)?;
                s.end()
            }

            TrieNode::Edge { child, path } => {
                let mut s = serializer.serialize_struct("ProofNode", 3)?;
                let p = Felt::from_bits(path).unwrap();
                let len = path.len();
                s.serialize_field("path", &p)?;
                s.serialize_field("length", &len)?;
                s.serialize_field("child", &child)?;
                s.end()
            }
        }
    }
}

impl<'de> Deserialize<'de> for ProofNode {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(field_identifier, rename_all = "snake_case")]
        enum Field {
            Left,
            Right,
            Path,
            Length,
            Child,
        }

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
                let mut left: Option<Felt> = None;
                let mut right: Option<Felt> = None;
                let mut path: Option<Felt> = None;
                let mut length: Option<usize> = None;
                let mut child: Option<Felt> = None;

                // 2. Loop over the strongly-typed `Field` enum.
                while let Some(key) = map.next_key()? {
                    match key {
                        Field::Left => {
                            if left.is_some() {
                                return Err(de::Error::duplicate_field("left"));
                            }
                            left = Some(map.next_value()?);
                        }
                        Field::Right => {
                            if right.is_some() {
                                return Err(de::Error::duplicate_field("right"));
                            }
                            right = Some(map.next_value()?);
                        }
                        Field::Path => {
                            if path.is_some() {
                                return Err(de::Error::duplicate_field("path"));
                            }
                            path = Some(map.next_value()?);
                        }
                        Field::Length => {
                            if length.is_some() {
                                return Err(de::Error::duplicate_field("length"));
                            }
                            length = Some(map.next_value()?);
                        }
                        Field::Child => {
                            if child.is_some() {
                                return Err(de::Error::duplicate_field("child"));
                            }
                            child = Some(map.next_value()?);
                        }
                    }
                }

                // Case 1: We have 'left' and 'right', indicating a Binary node.
                if let (Some(left), Some(right)) = (left, right) {
                    if path.is_some() || length.is_some() || child.is_some() {
                        return Err(de::Error::custom("found both Binary and Edge fields"));
                    }
                    Ok(ProofNode(TrieNode::Binary { left, right }))

                // Case 2: We have 'path', 'length', and 'child', indicating an Edge node.
                } else if let (Some(path_felt), Some(len), Some(child)) = (path, length, child) {
                    if left.is_some() || right.is_some() {
                        return Err(de::Error::custom("found both Binary and Edge fields"));
                    }
                    let path_bits = path_felt.view_bits().to_bitvec();
                    Ok(ProofNode(TrieNode::Edge {
                        child,
                        path: path_bits[path_bits.len() - len..].to_bitvec(),
                    }))

                // Case 3: The combination of fields is invalid.
                } else {
                    Err(de::Error::custom(
                        "missing fields: expected ('left', 'right') or ('path', 'length', 'child')",
                    ))
                }
            }
        }

        const FIELDS: &[&str] = &["left", "right", "path", "length", "child"];
        deserializer.deserialize_struct("ProofNode", FIELDS, ProofNodeVisitor)
    }
}
