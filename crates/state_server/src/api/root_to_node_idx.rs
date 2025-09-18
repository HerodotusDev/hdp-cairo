use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

use crate::{
    api::error::ApiError,
    mpt::{db::trie::TrieDB, error::Error as MptError},
    AppState,
};

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
) -> Result<Json<GetIdResponse>, ApiError> {
    let conn = state.get_connection(payload.trie_label).map_err(MptError::from)?;
    if payload.trie_root == Felt::ZERO {
        return Ok(Json(GetIdResponse {
            trie_root_node_idx: 0,
            trie_root: Felt::ZERO,
        }));
    }
    let trie_root_node_idx = TrieDB::new(&conn)
        .get_node_idx_by_hash(payload.trie_root)?
        .ok_or(ApiError::NotFound)?;

    Ok(Json(GetIdResponse {
        trie_root_node_idx,
        trie_root: payload.trie_root,
    }))
}
