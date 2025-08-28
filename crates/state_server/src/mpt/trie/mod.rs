use bitvec::{order::Msb0, slice::BitSlice};
use pathfinder_common::{hash::TruncatedKeccakHash, trie::TrieNode};
use pathfinder_crypto::Felt;
use pathfinder_merkle_tree::{
    merkle_node::Direction,
    tree::{MerkleTree, TrieNodeWithHash},
};
use pathfinder_storage::{Node, NodeRef, StoredNode, TrieStorageIndex, TrieUpdate};
use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;
use tracing::debug;
use types::proofs::injected_state::leaf::TrieLeaf;

use crate::mpt::{db::trie::TrieDB, error::Error};

pub struct Trie {}

#[derive(Debug, PartialEq)]
pub enum Membership {
    Member,
    NonMember,
}

/// The Trie struct represents a Merkle Trie data structure.
impl Trie {
    /// Loads a Trie from the given root index and database connection.
    ///
    /// # Arguments
    ///
    /// * `root_idx` - The root index of the Trie.
    /// * `conn` - The database connection.
    ///
    /// # Returns
    ///
    /// A new Trie instance.
    #[allow(dead_code)]
    pub fn load(
        root_idx: TrieStorageIndex,
        conn: &PooledConnection<SqliteConnectionManager>,
    ) -> (TrieDB, MerkleTree<TruncatedKeccakHash, 251>) {
        let storage = TrieDB::new(conn);
        let trie = MerkleTree::<TruncatedKeccakHash, 251>::new(root_idx);

        (storage, trie)
    }

    pub fn load_from_root<'a>(
        root: Felt,
        trie_label: Felt,
        conn: &'a PooledConnection<SqliteConnectionManager>,
    ) -> Result<(TrieDB<'a>, MerkleTree<TruncatedKeccakHash, 251>, TrieStorageIndex), Error> {
        let storage = TrieDB::new(conn);
        let root_idx_u64 = storage.get_node_idx_by_hash(root, trie_label)?.ok_or(Error::MissingNodeIndex)?;
        let root_idx = TrieStorageIndex::from(root_idx_u64);
        let trie = MerkleTree::<TruncatedKeccakHash, 251>::new(root_idx);

        Ok((storage, trie, root_idx))
    }

    /// Creates a new empty trie.
    ///
    /// # Arguments
    ///
    /// * `conn` - The database connection.
    ///
    /// # Returns
    ///
    /// A new empty Trie instance with storage, trie, and root index.
    pub fn create_empty(
        conn: &PooledConnection<SqliteConnectionManager>,
    ) -> Result<(TrieDB, MerkleTree<TruncatedKeccakHash, 251>, TrieStorageIndex), Error> {
        let storage = TrieDB::new(conn);
        let trie = MerkleTree::<TruncatedKeccakHash, 251>::empty();
        let root_idx = TrieStorageIndex::from(0);

        Ok((storage, trie, root_idx))
    }

    pub fn get_leaf_proof(storage: &TrieDB, root: Felt, leaf: TrieLeaf, trie_label: Felt) -> Result<Vec<TrieNodeWithHash>, Error> {
        // Convert the key to a bitvec for the trie
        let key_bits = leaf.get_path();
        let root_idx = storage.get_node_idx_by_hash(root, trie_label)?.unwrap();

        MerkleTree::<TruncatedKeccakHash, 251>::get_proof(root_idx.into(), storage, &key_bits).map_err(Error::GetProof)
    }

    // TODO this should return result not option
    pub fn verify_proof(proof: &[TrieNodeWithHash], root: Felt, leaf: TrieLeaf) -> Option<Membership> {
        let key = leaf.get_path();
        // Protect from ill-formed keys
        if key.len() != 251 {
            return None;
        }

        let mut expected_hash = root;
        let mut remaining_path: &BitSlice<u8, Msb0> = key.as_bitslice();
        for (proof_node, _) in proof.iter() {
            if proof_node.hash::<TruncatedKeccakHash>() != expected_hash {
                debug!("~~~~~~~~~~~~~PROOF VERIFICATION FAILED~~~~~~~~~~~~");
                debug!("Expected hash: {:?}", expected_hash);
                debug!("Proof node hash: {:?}", proof_node.hash::<TruncatedKeccakHash>());
                debug!("_______________________________");
                return None;
            }
            match proof_node {
                TrieNode::Binary { left, right } => {
                    let direction = Direction::from(remaining_path[0]);
                    expected_hash = match direction {
                        Direction::Left => *left,
                        Direction::Right => *right,
                    };
                    remaining_path = &remaining_path[1..];
                }
                TrieNode::Edge { child, path } => {
                    if path != &remaining_path[..path.len()] {
                        return Some(Membership::NonMember);
                    }

                    expected_hash = *child;

                    remaining_path = &remaining_path[path.len()..];
                }
            }
        }

        if remaining_path.is_empty() {
            if expected_hash == leaf.commitment() {
                Some(Membership::Member)
            } else {
                debug!("~~~~~~~~~~~~~PROOF VERIFICATION FAILED~~~~~~~~~~~~");
                debug!("Used Root: {:?}", root);
                debug!("expected hash: {:?}", expected_hash);
                debug!("leaf hash    : {:?}", leaf.commitment());
                debug!("_______________________________");
                None
            }
        } else if proof.is_empty() && root == Felt::ZERO {
            Some(Membership::NonMember)
        } else {
            debug!("~~~~~~~~~~~~~PROOF VERIFICATION FAILED~~~~~~~~~~~~");
            debug!("Path not fully consumed: {:?}", remaining_path);
            debug!("_______________________________");
            None
        }
    }

    /// Persists batch items and corresponding nodes to the TrieDB.
    ///
    /// # Arguments
    ///
    /// * `storage` - The TrieDB.
    /// * `update` - The TrieUpdate.
    /// * `items` - The items to be persisted.
    /// * `starting_index` - Optional starting index to replay from. If None, uses the maximum index + 1.
    ///
    /// # Returns
    ///
    /// A Result containing the root node index or an error.
    pub fn persist_updates(
        storage: &TrieDB,
        update: &TrieUpdate,
        items: &Vec<TrieLeaf>,
        starting_index: Option<u64>,
        trie_label: Felt,
    ) -> Result<TrieStorageIndex, Error> {
        let next_index = starting_index.unwrap_or_else(|| storage.get_node_idx().unwrap()) + 1;
        let mut nodes_to_persist: Vec<(StoredNode, Felt, u64)> = vec![];
        let mut root_index: Option<TrieStorageIndex> = None;

        // Insert new nodes into storage
        for (rel_index, (hash, node)) in update.nodes_added.iter().enumerate() {
            let node = match node {
                Node::Binary { left, right } => {
                    let left = match left {
                        NodeRef::StorageIndex(idx) => *idx,
                        NodeRef::Index(idx) => TrieStorageIndex::from(next_index + (*idx as u64)),
                    };

                    let right = match right {
                        NodeRef::StorageIndex(idx) => *idx,
                        NodeRef::Index(idx) => TrieStorageIndex::from(next_index + (*idx as u64)),
                    };

                    StoredNode::Binary { left, right }
                }
                Node::Edge { child, path } => {
                    let child = match child {
                        NodeRef::StorageIndex(idx) => *idx,
                        NodeRef::Index(idx) => TrieStorageIndex::from(next_index + (*idx as u64)),
                    };

                    StoredNode::Edge { child, path: path.clone() }
                }
                Node::LeafBinary => StoredNode::LeafBinary,
                Node::LeafEdge { path } => StoredNode::LeafEdge { path: path.clone() },
            };

            let index = next_index + (rel_index as u64);
            nodes_to_persist.push((node, *hash, index));

            // Track the root node index by matching the hash
            if *hash == update.root_commitment {
                root_index = Some(TrieStorageIndex::from(index));
            }
        }

        storage.persist_nodes(nodes_to_persist, trie_label)?;

        // Determine the final root index before persisting leaves
        let final_root_idx = if let Some(root_idx) = root_index {
            root_idx
        } else if let Some(idx) = storage
            .get_node_idx_by_hash(update.root_commitment, trie_label)?
            .map(TrieStorageIndex::from)
        {
            idx
        } else {
            // Fallback: create a placeholder root node so that subsequent look-ups succeed.
            let empty_root_node = StoredNode::LeafBinary;
            let root_idx = storage.get_node_idx()? + 1; // next available index after persistence
            let nodes_for_empty_root = vec![(empty_root_node, update.root_commitment, root_idx)];
            storage.persist_nodes(nodes_for_empty_root, trie_label)?;
            TrieStorageIndex::from(root_idx)
        };

        // Now persist the leaves with the final root index
        storage.persist_leafs(items, u64::from(final_root_idx), trie_label)?;

        Ok(final_root_idx)
    }
}
