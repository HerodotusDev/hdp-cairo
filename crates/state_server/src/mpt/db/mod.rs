use std::{collections::HashMap, sync::Arc};

pub mod trie;
use pathfinder_crypto::Felt;
use r2d2::{Pool, PooledConnection};
use r2d2_sqlite::SqliteConnectionManager;
use tracing::debug;

use crate::mpt::error::Error;

#[derive(Debug)]
pub struct ConnectionManager {
    db_root_path: Option<String>,
    pools: HashMap<Felt, Arc<Pool<SqliteConnectionManager>>>,
    is_memory_mode: bool,
}

impl ConnectionManager {
    /// Creates a new ConnectionManager with a connection pool to the specified database file.
    pub fn new(db_root_path: &str) -> Self {
        debug!("using root database path: {}", db_root_path);
        ConnectionManager {
            db_root_path: Some(db_root_path.to_string()),
            pools: HashMap::new(),
            is_memory_mode: false,
        }
    }

    /// Creates a new ConnectionManager for memory mode using in-memory databases.
    /// Each trie gets its own in-memory database to avoid collisions.
    pub fn new_memory() -> Self {
        debug!("using in-memory databases for memory mode");
        ConnectionManager {
            db_root_path: None,
            pools: HashMap::new(),
            is_memory_mode: true,
        }
    }

    /// Gets a connection from the pool.
    pub fn get_connection(&mut self, trie_label: Felt) -> Result<PooledConnection<SqliteConnectionManager>, Error> {
        if !self.pools.contains_key(&trie_label) {
            let manager = if self.is_memory_mode {
                // In memory mode, use in-memory databases with unique names to avoid collisions
                // Each trie gets its own in-memory database identified by the trie_label
                SqliteConnectionManager::memory()
            } else {
                // In file mode, use file-based databases
                let db_path = format!("{}/{}.db", self.db_root_path.as_ref().unwrap(), trie_label);
                std::fs::create_dir_all(self.db_root_path.as_ref().unwrap()).map_err(Error::Io)?;
                SqliteConnectionManager::file(db_path)
            };

            let pool = Pool::new(manager).map_err(Error::Pool)?;
            self.pools.insert(trie_label, Arc::new(pool));
        }

        Ok(self.pools.get(&trie_label).unwrap().get()?)
    }

    pub fn create_tables_if_not_exists(&mut self, trie_label: Felt) -> Result<(), Error> {
        self.get_connection(trie_label)?.execute(
            "CREATE TABLE IF NOT EXISTS trie_nodes (
                idx INTEGER PRIMARY KEY,
                hash BLOB NOT NULL,
                data BLOB,
                trie_idx INTEGER NOT NULL
            )",
            [],
        )?;

        self.get_connection(trie_label)?.execute(
            "CREATE TABLE IF NOT EXISTS leafs (
                idx INTEGER PRIMARY KEY,
                key BLOB NOT NULL,
                value BLOB NOT NULL,
                root_idx INTEGER NOT NULL
            )",
            [],
        )?;

        Ok(())
    }

    pub fn create_table(&mut self, trie_label: Felt) -> Result<(), Error> {
        // Drop existing tables first to ensure clean schema
        let _ = self.delete_tables(trie_label);

        self.get_connection(trie_label)?.execute(
            "CREATE TABLE trie_nodes (
                idx INTEGER PRIMARY KEY,
                hash BLOB NOT NULL,
                data BLOB,
                trie_idx INTEGER NOT NULL
            )",
            [],
        )?;

        self.get_connection(trie_label)?.execute(
            "CREATE TABLE leafs (
                idx INTEGER PRIMARY KEY,
                key BLOB NOT NULL,
                value BLOB NOT NULL,
                root_idx INTEGER NOT NULL
            )",
            [],
        )?;

        // self.get_connection()?.execute(
        //     "CREATE TABLE IF NOT EXISTS batches (
        //         id INTEGER PRIMARY KEY,
        //         parent_id INTEGER,
        //         status TEXT NOT NULL,
        //         root_idx INTEGER NOT NULL,
        //         FOREIGN KEY (parent_id) REFERENCES batches(id)
        //     )",
        //     [],
        // )?;

        Ok(())
    }

    /// Deletes all tables from the database.
    pub fn delete_tables(&mut self, trie_label: Felt) -> Result<(), Error> {
        // Drop the leafs table
        self.get_connection(trie_label)?.execute("DROP TABLE IF EXISTS leafs", [])?;

        // Drop the trie_nodes table
        self.get_connection(trie_label)?.execute("DROP TABLE IF EXISTS trie_nodes", [])?;

        // Uncomment if the batches table is added in the future
        // self.get_connection()?.execute("DROP TABLE IF EXISTS batches", [])?;

        Ok(())
    }
}
