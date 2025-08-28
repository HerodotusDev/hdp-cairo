use std::sync::Arc;

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
    pub connection_manager: Arc<ConnectionManager>,
}

impl AppState {
    pub fn new(db_path: &str) -> anyhow::Result<Self> {
        let connection_manager = ConnectionManager::new(db_path);
        connection_manager.create_tables_if_not_exists()?;

        Ok(Self {
            connection_manager: Arc::new(connection_manager),
        })
    }

    pub fn get_connection(&self) -> anyhow::Result<r2d2::PooledConnection<r2d2_sqlite::SqliteConnectionManager>> {
        Ok(self.connection_manager.get_connection()?)
    }
}

pub fn create_router(state: AppState) -> Router {
    Router::new()
        .route("/create_trie", post(create_trie))
        .route("/get_trie_root_node_idx", get(get_trie_root_node_idx))
        .route("/get_state_proofs", post(get_state_proofs))
        .route("/read", get(read))
        .route("/write", get(write))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
