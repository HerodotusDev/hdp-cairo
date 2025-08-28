use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};

use crate::{mpt::db::trie::TrieDB, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct GetIdRequest {
    pub trie_label: Felt,
    pub trie_root: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetIdResponse {
    pub trie_root_node_idx: u64,
    pub trie_root: Felt,
}

pub async fn get_trie_root_node_idx(
    State(state): State<AppState>,
    Query(payload): Query<GetIdRequest>,
) -> Result<Json<GetIdResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if payload.trie_root == Felt::ZERO {
        return Ok(Json(GetIdResponse {
            trie_root_node_idx: 0,
            trie_root: Felt::ZERO,
        }));
    }

    let trie_root_node_idx = TrieDB::new(&conn)
        .get_node_idx_by_hash(payload.trie_root, payload.trie_label)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(GetIdResponse {
        trie_root_node_idx,
        trie_root: payload.trie_root,
    }))
}
