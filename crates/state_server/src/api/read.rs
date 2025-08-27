use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};

use crate::{mpt::trie::Trie, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadRequest {
    pub trie_label: Felt,
    pub trie_root: Felt,
    pub key: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadResponse {
    pub key: Felt,
    pub value: Felt,
}

pub async fn read(State(state): State<AppState>, Query(payload): Query<ReadRequest>) -> Result<Json<ReadResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (storage, _trie, root_idx) = if payload.trie_root == Felt::ZERO {
        Trie::create_empty(&conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
    } else {
        Trie::load_from_root(payload.trie_root, payload.trie_label, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
    };

    let leaf = storage
        .get_leaf_at(payload.key, u64::from(root_idx), payload.trie_label)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(ReadResponse {
        key: payload.key,
        value: leaf.data.value,
    }))
}
