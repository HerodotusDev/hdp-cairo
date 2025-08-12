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

use crate::{db::trie::TrieDB, error::Error, state_server_types::trie::leaf::TrieLeaf};

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

    pub fn load_from_root(
        root: Felt,
        conn: &PooledConnection<SqliteConnectionManager>,
    ) -> Result<(TrieDB, MerkleTree<TruncatedKeccakHash, 251>, TrieStorageIndex), Error> {
        let storage = TrieDB::new(conn);
        let root_idx_u64 = storage.get_node_idx_by_hash(root)?.ok_or(Error::MissingNodeIndex)?;
        let root_idx = TrieStorageIndex::from(root_idx_u64);
        let trie = MerkleTree::<TruncatedKeccakHash, 251>::new(root_idx);

        Ok((storage, trie, root_idx))
    }

    pub fn persist_changes(
        storage: &mut TrieDB,
        trie: &MerkleTree<TruncatedKeccakHash, 251>,
        leafs: Vec<TrieLeaf>,
    ) -> Result<TrieUpdate, Error> {
        let update = trie.clone().commit(storage)?;
        let _root_idx = Trie::persist_updates(storage, &update, &leafs)?;

        Ok(update)
    }

    pub fn get_leaf_proof(storage: &TrieDB, root: Felt, leaf: TrieLeaf) -> Result<Vec<TrieNodeWithHash>, Error> {
        // Convert the key to a bitvec for the trie
        let key_bits = leaf.get_path();
        let root_idx = storage.get_node_idx_by_hash(root)?.unwrap();

        MerkleTree::<TruncatedKeccakHash, 251>::get_proof(root_idx.into(), storage, &key_bits).map_err(Error::GetProof)
    }

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
                println!("~~~~~~~~~~~~~PROOF VERIFICATION FAILED~~~~~~~~~~~~");
                println!("Expected hash: {:?}", expected_hash);
                println!("Proof node hash: {:?}", proof_node.hash::<TruncatedKeccakHash>());
                println!("_______________________________");
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

        assert!(remaining_path.is_empty(), "Proof path should be empty");
        if expected_hash == leaf.commitment() {
            Some(Membership::Member)
        } else {
            println!("~~~~~~~~~~~~~PROOF VERIFICATION FAILED~~~~~~~~~~~~");
            println!("Used Root: {:?}", root);
            println!("expected hash: {:?}", expected_hash);
            println!("leaf hash    : {:?}", leaf.commitment());
            println!("_______________________________");
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
    ///
    /// # Returns
    ///
    /// A Result containing the root node index or an error.
    pub fn persist_updates(storage: &TrieDB, update: &TrieUpdate, items: &Vec<TrieLeaf>) -> Result<TrieStorageIndex, Error> {
        let next_index = storage.get_node_idx()? + 1;
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

        storage.persist_nodes(nodes_to_persist)?;
        storage.persist_leafs(items)?;

        // First, try using the index we tracked while iterating over nodes_added.
        if let Some(root_idx) = root_index {
            return Ok(root_idx);
        }

        // If we didn't find the root in nodes_added, attempt to look it up now that we've
        // persisted all nodes. This covers the common case where the root already existed in
        // storage before the update (so it wasn't part of nodes_added).
        if let Some(idx) = storage.get_node_idx_by_hash(update.root_commitment)?.map(TrieStorageIndex::from) {
            return Ok(idx);
        }

        // Fallback: create a placeholder root node so that subsequent look-ups succeed.
        let empty_root_node = StoredNode::LeafBinary;
        let root_idx = storage.get_node_idx()? + 1; // next available index after persistence
        let nodes_for_empty_root = vec![(empty_root_node, update.root_commitment, root_idx)];
        storage.persist_nodes(nodes_for_empty_root)?;
        Ok(TrieStorageIndex::from(root_idx))
    }
}
