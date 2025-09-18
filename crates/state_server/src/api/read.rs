use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

use crate::{api::error::ApiError, mpt::trie::Trie, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadRequest {
    pub trie_label: Felt,
    pub trie_root: Felt,
    pub key: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ReadResponse {
    pub key: Felt,
    pub value: Option<Felt>,
}

pub async fn read(State(state): State<AppState>, Query(payload): Query<ReadRequest>) -> Result<Json<ReadResponse>, ApiError> {
    let conn = state.get_connection(payload.trie_label)?;
    let (storage, _trie, root_idx) = if payload.trie_root == Felt::ZERO {
        Trie::create_empty(&conn)?
    } else {
        Trie::load_from_root(payload.trie_root, &conn)?
    };
    let leaf = storage.get_leaf_at(payload.key, u64::from(root_idx))?;

    Ok(Json(ReadResponse {
        key: payload.key,
        value: leaf.map(|leaf| leaf.data.value),
    }))
}
