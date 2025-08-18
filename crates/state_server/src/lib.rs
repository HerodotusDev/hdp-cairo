use std::sync::Arc;

use axum::{routing::get, Router};
use tokio::net::TcpListener;
use tower_http::{cors::CorsLayer, trace::TraceLayer};

use crate::{
    api::{key::get_key, proof::get_state_proofs, root::get_root_hash_by_id},
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

// Router setup
pub fn create_router() -> Router {
    let state = AppState::new("a.db").unwrap();

    Router::new()
        .route("/get-key", get(get_key))
        .route("/get-root-hash", get(get_root_hash_by_id))
        .route("/get-state-proofs", get(get_state_proofs))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

// Server startup
pub async fn start_server(port: u16) -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let app = create_router();
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;

    axum::serve(listener, app).await?;
    Ok(())
}
