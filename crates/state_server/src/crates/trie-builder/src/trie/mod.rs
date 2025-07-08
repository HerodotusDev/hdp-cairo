use std::collections::HashMap;

use bitvec::{order::Msb0, slice::BitSlice, vec::BitVec};
use pathfinder_common::{hash::TruncatedKeccakHash, trie::TrieNode};
use pathfinder_crypto::Felt;
use pathfinder_merkle_tree::{merkle_node::Direction, tree::MerkleTree};
use pathfinder_storage::{Node, NodeRef, StoredNode, TrieStorageIndex, TrieUpdate};
use primitive_types::U256;
use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;

use crate::{
    db::trie::TrieDB,
    error::Error,
    state_server_types::trie::{
        contract::VerificationCallData,
        leaf::{LeafUpdate, TrieLeaf, generate_preimage},
    },
};

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

    pub fn init(conn: &PooledConnection<SqliteConnectionManager>) -> (TrieDB, Felt, TrieStorageIndex) {
        let mut trie = MerkleTree::<TruncatedKeccakHash, 251>::empty();
        let storage = TrieDB::new(conn);

        let item = TrieLeaf::new(Felt::ZERO, Felt::ZERO);
        let _ = trie.set(&storage, item.get_path(), item.commitment());
        let update = trie.clone().commit(&storage).unwrap();
        let root_idx = Trie::persist_updates(&storage, &update, &vec![item]).unwrap();

        (storage, update.root_commitment, root_idx)
    }

    #[allow(clippy::type_complexity)]
    pub fn generate_update_proofs(
        trie: &mut MerkleTree<TruncatedKeccakHash, 251>,
        storage: &mut TrieDB,
        updates: &[LeafUpdate],
        root_idx: TrieStorageIndex,
    ) -> Result<(HashMap<String, Vec<String>>, Felt, Vec<VerificationCallData>), Error> {
        let pre_root = storage.get_node_hash_by_idx(root_idx.into())?.unwrap();
        let mut pre_proofs: Vec<Vec<(TrieNode, Felt)>> = Vec::new();
        let mut post_proofs: Vec<Vec<(TrieNode, Felt)>> = Vec::new();
        let mut verification_call_data: Vec<VerificationCallData> = Vec::new();

        for update in updates {
            let proof = Trie::get_leaf_proof(storage, pre_root, update.as_old_leaf())?;
            let pre_ok = Trie::verify_proof(&proof.clone(), pre_root, update.as_old_leaf());

            assert!(pre_ok.is_some(), "Pre proof verification failed");
            pre_proofs.push(proof.clone());
            let verification_data = VerificationCallData::from_proof(&proof, &update.as_old_leaf(), pre_root);
            verification_call_data.push(verification_data);
        }

        let updated_leafs = updates.to_owned().iter().map(|u| u.as_new_leaf()).collect();
        let update = Trie::persist_changes(storage, trie, updated_leafs)?;
        let post_root = update.root_commitment;

        for update in updates {
            let proof = Trie::get_leaf_proof(storage, post_root, update.as_new_leaf())?;
            let post_ok = Trie::verify_proof(&proof.clone(), post_root, update.as_new_leaf());

            assert!(post_ok.is_some(), "Post proof verification failed");
            post_proofs.push(proof.clone());
            let verification_data = VerificationCallData::from_proof(&proof, &update.as_new_leaf(), post_root);
            verification_call_data.push(verification_data);
        }

        let mut preimage = HashMap::new();
        for (pre_proof, post_proof) in pre_proofs.iter().zip(post_proofs.iter()) {
            generate_preimage::<TruncatedKeccakHash>(&mut preimage, pre_proof.clone());
            generate_preimage::<TruncatedKeccakHash>(&mut preimage, post_proof.clone());
        }
        Ok((preimage, post_root, verification_call_data))
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

    pub fn get_leaf_proof(storage: &TrieDB, root: Felt, leaf: TrieLeaf) -> Result<Vec<(TrieNode, Felt)>, Error> {
        // Convert the key to a bitvec for the trie
        let key_bits = leaf.get_path();
        let root_idx = storage.get_node_idx_by_hash(root)?.unwrap();

        MerkleTree::<TruncatedKeccakHash, 251>::get_proof(root_idx.into(), storage, &key_bits).map_err(Error::GetProof)
    }

    pub fn get_proof(storage: &TrieDB, root_idx: TrieStorageIndex, address: Felt) -> Result<Vec<[U256; 3]>, Error> {
        let key_bits = address.view_bits().to_bitvec();
        let proof = MerkleTree::<TruncatedKeccakHash, 251>::get_proof(root_idx, storage, &key_bits).map_err(Error::GetProof)?;

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
                        bits_to_u256(&path),
                        U256([0, 0, 0, 1u64 << 63]) | U256::from(path_len),
                    ]
                }
            };
            packed_nodes.push(packed_node);
        }

        Ok(packed_nodes)
    }

    pub fn verify_proof(proof: &[(TrieNode, Felt)], root: Felt, leaf: TrieLeaf) -> Option<Membership> {
        let key = leaf.get_path();
        // Protect from ill-formed keys
        if key.len() != 251 {
            return None;
        }

        let mut expected_hash = root;
        let mut remaining_path: &BitSlice<u8, Msb0> = key.as_bitslice();
        for (proof_node, _) in proof.iter() {
            if proof_node.hash::<TruncatedKeccakHash>() != expected_hash {
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
            println!("proof: {:?}", proof);
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

/// Converts a BitSlice (using Msb0 order) to a U256 (big-endian).
/// The bits are right-aligned (padded with leading zeros) in the resulting U256.
fn bits_to_u256(bits: &BitVec<u8, Msb0>) -> U256 {
    let felt = Felt::from_bits(bits).expect("Failed to convert bits to Felt; check bit length compatibility.");

    // Convert the Felt to its big-endian byte representation ([u8; 32]).
    let felt_bytes = felt.to_be_bytes();

    // Create the U256 directly from the big-endian bytes provided by Felt.
    U256::from_big_endian(&felt_bytes)
}
