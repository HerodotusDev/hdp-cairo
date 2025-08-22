use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};

use crate::{
    mpt::{error::Error, trie::Trie},
    AppState,
};

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadRequest {
    pub trie_root: Felt,
    pub key: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadResponse {
    pub key: Felt,
    pub value: Option<Felt>,
}

pub async fn read(State(state): State<AppState>, Query(payload): Query<ReadRequest>) -> Result<Json<ReadResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let (storage, _trie, _root_idx) = Trie::load_from_root(payload.trie_root, &conn).map_err(|e| {
        if let Error::MissingNodeIndex = e {
            StatusCode::NOT_FOUND
        } else {
            StatusCode::INTERNAL_SERVER_ERROR
        }
    })?;
    let leaf = storage.get_leaf(payload.key).ok();

    Ok(Json(ReadResponse {
        key: payload.key,
        // TODO: add a way to distinguish empty leaf from zero-valued leaf
        value: leaf.map(|leaf| leaf.data.value),
    }))
}
