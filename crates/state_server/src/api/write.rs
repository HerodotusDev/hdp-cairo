use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use types::proofs::injected_state::leaf::TrieLeaf;

use crate::{mpt::trie::Trie, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct WriteRequest {
    pub trie_root: Felt,
    pub key: Felt,
    pub value: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WriteResponse {
    pub trie_id: u64,
    pub trie_root: Felt,
    pub key: Felt,
    pub value: Option<Felt>,
}

pub async fn write(State(state): State<AppState>, Query(payload): Query<WriteRequest>) -> Result<Json<WriteResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (storage, mut trie, _root_idx) = Trie::load_from_root(payload.trie_root, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let pre_leaf = storage.get_leaf(payload.key);

    let leaf = TrieLeaf::new(payload.key, payload.value);
    trie.set(&storage, leaf.get_path(), leaf.data.value)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let update = trie.commit(&storage).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let trie_id = Trie::persist_updates(&storage, &update, &vec![leaf]).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(WriteResponse {
        trie_id: u64::from(trie_id),
        trie_root: payload.trie_root,
        key: leaf.key,
        value: pre_leaf.ok().map(|leaf| leaf.data.value),
    }))
}
