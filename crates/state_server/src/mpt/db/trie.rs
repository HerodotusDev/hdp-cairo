use bitvec::{order::Msb0, slice::BitSlice};
use pathfinder_crypto::Felt;
use pathfinder_merkle_tree::storage::Storage;
use pathfinder_storage::{StoredNode, TrieStorageIndex};
use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;
use rusqlite::{params, OptionalExtension};
use types::proofs::injected_state::leaf::TrieLeaf;

use crate::mpt::error::Error;

/// Represents a Trie database.
#[derive(Debug, Clone, Copy)]
pub struct TrieDB<'a> {
    conn: &'a PooledConnection<SqliteConnectionManager>,
}

impl<'a> TrieDB<'a> {
    /// Creates a new instance of `TrieDB`.
    ///
    /// # Arguments
    ///
    /// * `conn` - A reference to a pooled SQLite connection.
    pub fn new(conn: &'a PooledConnection<SqliteConnectionManager>) -> Self {
        Self { conn }
    }

    /// Persists the leaves in the database, skipping any (key, value) pairs that already exist.
    ///
    /// # Arguments
    ///
    /// * `leaves` - A vector of `TrieLeaf` representing the leaves to be persisted.
    /// * `root_idx` - The trie root index to associate with these leaves.
    ///
    /// # Errors
    ///
    /// Returns a `Error` if there was an error persisting the leaves.
    pub fn persist_leafs(&self, leaves: &Vec<TrieLeaf>, root_idx: u64) -> Result<(), Error> {
        const SELECT_QUERY: &str = "SELECT 1 FROM leafs WHERE key = ?1 AND value = ?2";
        const INSERT_QUERY: &str = "INSERT INTO leafs (key, value, root_idx) VALUES (?1, ?2, ?3)";

        for item in leaves {
            let key_bytes = item.get_key().to_be_bytes().to_vec();
            let value_bytes = item.data.value.to_be_bytes().to_vec();

            // Check if the (key, value) pair already exists
            let mut stmt = self.conn.prepare_cached(SELECT_QUERY)?;
            let exists: Option<u8> = stmt.query_row(params![&key_bytes, &value_bytes], |row| row.get(0)).optional()?;

            if exists.is_none() {
                self.conn
                    .execute(INSERT_QUERY, params![&key_bytes, &value_bytes, root_idx])
                    .map_err(Error::from)?;
            }
        }

        Ok(())
    }

    pub fn delete_leaf(&self, key: Felt) -> Result<(), Error> {
        const DELETE_QUERY: &str = "DELETE FROM leafs WHERE key = ?";
        self.conn
            .execute(DELETE_QUERY, params![key.to_be_bytes().to_vec()])
            .map_err(Error::from)?;
        Ok(())
    }

    /// Persists the nodes in the database.
    ///
    /// # Arguments
    ///
    /// * `nodes` - A vector of tuples representing the nodes to be persisted. Each tuple contains a `StoredNode`, a `Felt` hash, and a trie
    ///   index.
    ///
    /// # Errors
    ///
    /// Returns a `Error` if there was an error persisting the nodes.
    pub fn persist_nodes(&self, nodes: Vec<(StoredNode, Felt, u64)>) -> Result<(), Error> {
        // We'll check for existence before inserting to avoid duplicates.
        const SELECT_QUERY: &str = "SELECT 1 FROM trie_nodes WHERE trie_idx = ?";
        const INSERT_QUERY: &str = "INSERT INTO trie_nodes (hash, data, trie_idx) VALUES (?1, ?2, ?3)";
        let mut write_buffer = [0u8; 256];
        for (node, hash, trie_idx) in nodes {
            let length = node.encode(&mut write_buffer)?;
            let hash_bytes = hash.to_be_bytes().to_vec();
            let data_bytes = write_buffer[..length].to_vec();

            // Check if a node with the same trie_idx already exists
            let mut stmt = self.conn.prepare_cached(SELECT_QUERY)?;
            let exists: Option<u8> = stmt.query_row(params![trie_idx], |row| row.get(0)).optional()?;

            if exists.is_none() {
                // Only insert if not already present
                self.conn
                    .execute(INSERT_QUERY, params![&hash_bytes, &data_bytes, trie_idx])
                    .map_err(Error::from)?;
            }
        }

        Ok(())
    }

    /// Retrieves the maximum trie index from the database.
    ///
    /// # Errors
    ///
    /// Returns a `Error` if there was an error retrieving the trie index.
    pub fn get_node_idx(&self) -> Result<u64, Error> {
        let mut stmt = self.conn.prepare_cached("SELECT MAX(trie_idx) FROM trie_nodes")?;

        let trie_idx: Option<u64> = stmt
            .query_row([], |row| row.get::<_, Option<u64>>(0))
            .optional()? // Using optional to handle no rows found situation gracefully
            .flatten(); // Flatten to convert Option<Option<u64>> to Option<u64>

        Ok(trie_idx.map_or(0, |idx| idx))
    }

    /// Retrieves the trie index for a given node hash.
    ///
    /// # Arguments
    ///
    /// * `hash` - The hash of the node to find the index for.
    ///
    /// # Errors
    ///
    /// Returns an `Error` if there was a database error.
    ///
    /// # Returns
    ///
    /// Returns `Ok(Some(index))` if the hash is found, `Ok(None)` otherwise.
    pub fn get_node_idx_by_hash(&self, hash: Felt) -> Result<Option<u64>, Error> {
        let mut stmt = self.conn.prepare_cached("SELECT trie_idx FROM trie_nodes WHERE hash = ?")?;

        let index: Option<u64> = stmt.query_row(params![hash.to_be_bytes().to_vec()], |row| row.get(0)).optional()?;

        Ok(index)
    }

    /// Retrieves the node hash for a given trie index.
    ///
    /// # Arguments
    ///
    /// * `idx` - The index of the node to find the hash for.
    ///
    /// # Errors
    ///
    /// Returns an `Error` if there was a database error.
    ///
    /// # Returns
    ///
    /// Returns `Ok(Some(hash))` if the index is found, `Ok(None)` otherwise.
    pub fn get_node_hash_by_idx(&self, idx: u64) -> Result<Option<Felt>, Error> {
        let mut stmt = self.conn.prepare_cached("SELECT hash FROM trie_nodes WHERE trie_idx = ?")?;

        let hash_bytes: Option<Vec<u8>> = stmt
            .query_row(params![idx], |row| row.get(0))
            .optional() // Handle case where index is not found
            .map_err(Error::from)?; // Convert rusqlite error to custom Error

        match hash_bytes {
            Some(bytes) => {
                let hash = Felt::from_be_slice(&bytes).unwrap();
                Ok(Some(hash))
            }
            None => Ok(None),
        }
    }

    /// Retrieves the leaf at the given key. This is used to get the latest leaf for a given key.
    ///
    /// # Arguments
    ///
    /// * `key` - The key of the leaf to retrieve.
    ///
    /// # Returns
    ///
    /// Returns `Ok(leaf)` if the leaf is found, `Ok(TrieLeaf::empty(key))` otherwise.
    pub fn get_leaf(&self, key: Felt) -> anyhow::Result<TrieLeaf> {
        let mut stmt = self.conn.prepare_cached("SELECT value FROM leafs WHERE key = ?")?;
        let result: Option<TrieLeaf> = stmt
            .query_row(params![key.to_be_bytes().to_vec()], |row| {
                let value: Vec<u8> = row.get(0)?;
                let value = Felt::from_be_slice(&value).unwrap();
                Ok(TrieLeaf::new(key, value))
            })
            .optional()?;

        match result {
            Some(leaf) => Ok(leaf),
            None => Ok(TrieLeaf::empty(key)),
        }
    }

    /// Retrieves the leaf at the given key and root index.
    /// This is used to get the leaf at a specific trie checkpoint.
    ///
    /// # Arguments
    ///
    /// * `key` - The key of the leaf to retrieve.
    /// * `max_root_idx` - The maximum root index to consider.
    ///
    /// # Returns
    ///
    /// Returns `Ok(leaf)` if the leaf is found, `Ok(TrieLeaf::empty(key))` otherwise.
    pub fn get_leaf_at(&self, key: Felt, max_root_idx: u64) -> anyhow::Result<TrieLeaf> {
        let mut stmt = self
            .conn
            .prepare_cached("SELECT value FROM leafs WHERE key = ? AND root_idx <= ? ORDER BY idx DESC LIMIT 1")?;

        let result: Option<TrieLeaf> = stmt
            .query_row(params![key.to_be_bytes().to_vec(), max_root_idx], |row| {
                let value: Vec<u8> = row.get(0)?;
                let value = Felt::from_be_slice(&value).unwrap();

                let leaf = TrieLeaf::new(key, value);

                assert!(leaf.commitment() == value, "Value mismatch");

                Ok(leaf)
            })
            .optional()?;

        match result {
            Some(leaf) => Ok(leaf),
            None => Ok(TrieLeaf::empty(key)),
        }
    }
}

impl Storage for TrieDB<'_> {
    /// Retrieves the stored node at the specified index from the trie database.
    ///
    /// # Arguments
    ///
    /// * `index` - The index of the node to retrieve.
    ///
    /// # Returns
    ///
    /// Returns `Ok(None)` if no node is found at the specified index.
    /// Otherwise, returns `Ok(Some(node))` where `node` is the retrieved stored node.
    fn get(&self, index: TrieStorageIndex) -> anyhow::Result<Option<StoredNode>> {
        let mut stmt = self.conn.prepare_cached("SELECT data FROM trie_nodes WHERE trie_idx = ?")?;

        let Some(data): Option<Vec<u8>> = stmt.query_row(params![&index.0], |row| row.get(0)).optional()? else {
            return Ok(None);
        };

        let node = StoredNode::decode(&data)?;

        Ok(Some(node))
    }

    /// Retrieves the hash value of the stored node at the specified index from the trie database.
    ///
    /// # Arguments
    ///
    /// * `index` - The index of the node to retrieve the hash value for.
    ///
    /// # Returns
    ///
    /// Returns `Ok(None)` if no node is found at the specified index.
    /// Otherwise, returns `Ok(Some(hash))` where `hash` is the retrieved hash value.
    fn hash(&self, index: TrieStorageIndex) -> anyhow::Result<Option<Felt>> {
        let mut stmt = self.conn.prepare_cached("SELECT hash FROM trie_nodes WHERE trie_idx = ?")?;

        let Some(data): Option<Vec<u8>> = stmt.query_row(params![&index.0], |row| row.get(0)).optional()? else {
            return Ok(None);
        };

        Ok(Some(Felt::from_be_slice(&data)?))
    }

    /// Retrieves the leaf value associated with the specified path from the trie database.
    /// This version retrieves the *latest* version of the leaf based on insertion order,
    /// assuming an auto-incrementing primary key 'id' exists in the 'leafs' table.
    /// Note: This method is used by the merkle tree implementation and should get the latest leaf.
    ///
    /// # Arguments
    ///
    /// * `path` - The path of the leaf to retrieve.
    ///
    /// # Returns
    ///
    /// Returns `Ok(None)` if no leaf is found at the specified path.
    /// Otherwise, returns `Ok(Some(leaf))` where `leaf` is the retrieved leaf value.
    fn leaf(&self, path: &BitSlice<u8, Msb0>) -> anyhow::Result<Option<Felt>> {
        let mut stmt = self
            .conn
            .prepare_cached("SELECT value FROM leafs WHERE key = ? ORDER BY idx DESC LIMIT 1")?;

        // Execute the query
        let Some(data): Option<Vec<u8>> = stmt
            .query_row(params![Felt::from_bits(path)?.to_be_bytes().to_vec()], |row| row.get(0))
            .optional()?
        else {
            // No leaf found for this key
            return Ok(None);
        };

        Ok(Some(Felt::from_be_slice(&data)?))
    }
}
