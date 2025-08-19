use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};

use crate::{mpt::db::trie::TrieDB, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct GetRootRequest {
    pub trie_id: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetRootResponse {
    pub trie_id: u64,
    pub trie_root: Felt,
}

pub async fn get_trie_root_by_id(
    State(state): State<AppState>,
    Query(payload): Query<GetRootRequest>,
) -> Result<Json<GetRootResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let trie_root = TrieDB::new(&conn)
        .get_node_hash_by_idx(payload.trie_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(GetRootResponse {
        trie_id: payload.trie_id,
        trie_root,
    }))
}
