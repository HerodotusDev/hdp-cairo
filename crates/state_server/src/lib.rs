use std::sync::Arc;

use axum::{
    routing::{get, post},
    Router,
};
use tower_http::{cors::CorsLayer, trace::TraceLayer};

use crate::{
    api::{proof::get_state_proofs, read::read, root_to_id::get_id_by_trie_root, write::write},
    mpt::db::ConnectionManager,
};

pub mod api;
pub mod mpt;

#[derive(Debug, Clone)]
pub struct AppState {
    connection_manager: Arc<ConnectionManager>,
}

impl AppState {
    pub fn new(db_path: &str) -> anyhow::Result<Self> {
        let connection_manager = ConnectionManager::new(db_path);
        connection_manager.create_tables_if_not_exists()?;

        Ok(Self {
            connection_manager: Arc::new(connection_manager),
        })
    }
}

pub fn create_router() -> Router {
    let state = AppState::new("a.db").unwrap();

    Router::new()
        .route("/get_id_by_trie_root", get(get_id_by_trie_root))
        .route("/get_state_proofs", post(get_state_proofs))
        .route("/read", get(read))
        .route("/write", get(write))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
