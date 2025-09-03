use std::sync::{Arc, Mutex};

use axum::{
    routing::{get, post},
    Router,
};
use tower_http::{cors::CorsLayer, trace::TraceLayer};

use crate::{
    api::{create_trie::create_trie, proof::get_state_proofs, read::read, root_to_node_idx::get_trie_root_node_idx, write::write},
    mpt::db::ConnectionManager,
};

pub mod api;
pub mod mpt;

#[derive(Debug, Clone)]
pub struct AppState {
    pub connection_manager: Arc<Mutex<ConnectionManager>>,
}

impl AppState {
    pub fn new(db_root_path: &str) -> anyhow::Result<Self> {
        let connection_manager = ConnectionManager::new(db_root_path);

        Ok(Self {
            connection_manager: Arc::new(Mutex::new(connection_manager)),
        })
    }

    /// Creates a new AppState for memory mode using in-memory databases.
    pub fn new_memory() -> anyhow::Result<Self> {
        let connection_manager = ConnectionManager::new_memory();

        Ok(Self {
            connection_manager: Arc::new(Mutex::new(connection_manager)),
        })
    }

    pub fn get_connection(
        &self,
        trie_label: pathfinder_crypto::Felt,
    ) -> anyhow::Result<r2d2::PooledConnection<r2d2_sqlite::SqliteConnectionManager>> {
        self.connection_manager.lock().unwrap().create_tables_if_not_exists(trie_label)?;
        Ok(self.connection_manager.lock().unwrap().get_connection(trie_label)?)
    }
}

pub fn create_router(state: AppState) -> Router {
    Router::new()
        // GET
        .route("/get_trie_root_node_idx", get(get_trie_root_node_idx))
        .route("/read", get(read))
        // POST
        .route("/get_state_proofs", post(get_state_proofs))
        .route("/write", post(write))
        .route("/create_trie", post(create_trie))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
