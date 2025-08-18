use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};

use crate::{mpt::trie::Trie, AppState};

#[derive(Deserialize)]
pub struct GetKeyRequest {
    trie_root: Felt,
    key: Felt,
}

#[derive(Serialize)]
pub struct GetKeyResponse {
    trie_root: Felt,
    key: Felt,
    value: Felt,
}

pub async fn get_key(State(state): State<AppState>, Query(payload): Query<GetKeyRequest>) -> Result<Json<GetKeyResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (storage, _trie, _root_idx) = Trie::load_from_root(payload.trie_root, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let leaf = storage.get_leaf(payload.key).map_err(|_| StatusCode::NOT_FOUND)?;

    Ok(Json(GetKeyResponse {
        trie_root: payload.trie_root,
        key: leaf.key,
        value: leaf.data.value,
    }))
}
