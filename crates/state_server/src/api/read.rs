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
    pub trie_root: Felt,
    pub key: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadResponse {
    pub trie_root: Felt,
    pub key: Felt,
    pub value: Option<Felt>,
}

pub async fn read(State(state): State<AppState>, Query(payload): Query<ReadRequest>) -> Result<Json<ReadResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (storage, _trie, _root_idx) = Trie::load_from_root(payload.trie_root, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let leaf = storage.get_leaf(payload.key).ok();

    Ok(Json(ReadResponse {
        trie_root: payload.trie_root,
        key: payload.key,
        value: leaf.map(|leaf| leaf.data.value),
    }))
}
