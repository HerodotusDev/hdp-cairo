use std::sync::Arc;

pub mod trie;
use r2d2::{Pool, PooledConnection};
use r2d2_sqlite::SqliteConnectionManager;

use crate::error::Error;

#[derive(Debug)]
pub struct ConnectionManager {
    pool: Arc<Pool<SqliteConnectionManager>>,
}

impl ConnectionManager {
    /// Creates a new ConnectionManager with a connection pool to the specified database file.
    pub fn new(file: &str) -> Self {
        let manager = SqliteConnectionManager::file(file);
        let pool = Pool::new(manager).unwrap();
        ConnectionManager { pool: Arc::new(pool) }
    }

    /// Gets a connection from the pool.
    pub fn get_connection(&self) -> Result<PooledConnection<SqliteConnectionManager>, Error> {
        Ok(self.pool.get()?)
    }

    pub fn create_tables_if_not_exists(&self) -> Result<(), Error> {
        self.get_connection()?.execute(
            "CREATE TABLE IF NOT EXISTS trie_nodes (
                idx INTEGER PRIMARY KEY,
                hash BLOB NOT NULL,
                data BLOB,
                trie_idx INTEGER UNIQUE NOT NULL
            )",
            [],
        )?;

        self.get_connection()?.execute(
            "CREATE TABLE IF NOT EXISTS leafs (
                idx INTEGER PRIMARY KEY,
                key BLOB NOT NULL,
                value BLOB NOT NULL
            )",
            [],
        )?;

        Ok(())
    }

    pub fn create_table(&self) -> Result<(), Error> {
        // Drop existing tables first to ensure clean schema
        let _ = self.delete_tables();

        self.get_connection()?.execute(
            "CREATE TABLE trie_nodes (
                idx INTEGER PRIMARY KEY,
                hash BLOB NOT NULL,
                data BLOB,
                trie_idx INTEGER UNIQUE NOT NULL
            )",
            [],
        )?;

        self.get_connection()?.execute(
            "CREATE TABLE leafs (
                idx INTEGER PRIMARY KEY,
                key BLOB NOT NULL,
                value BLOB NOT NULL
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
    pub fn delete_tables(&self) -> Result<(), Error> {
        // Drop the leafs table
        self.get_connection()?.execute("DROP TABLE IF EXISTS leafs", [])?;

        // Drop the trie_nodes table
        self.get_connection()?.execute("DROP TABLE IF EXISTS trie_nodes", [])?;

        // Uncomment if the batches table is added in the future
        // self.get_connection()?.execute("DROP TABLE IF EXISTS batches", [])?;

        Ok(())
    }
}
