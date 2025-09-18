use axum::{extract::State, Json};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};
use types::proofs::injected_state::leaf::TrieLeaf;

use crate::{
    api::error::ApiError,
    mpt::{error::Error as MptError, trie::Trie},
    AppState,
};

#[derive(Debug, Serialize, Deserialize)]
pub struct WriteRequest {
    pub trie_label: Felt,
    pub trie_root: Felt,
    pub key: Felt,
    pub value: Felt,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WriteResponse {
    pub trie_id: u64,
    pub trie_root: Felt,
    pub key: Felt,
    pub value: Felt,
}

pub async fn write(State(state): State<AppState>, Json(payload): Json<WriteRequest>) -> Result<Json<WriteResponse>, ApiError> {
    let conn = state.get_connection(payload.trie_label).map_err(MptError::from)?;
    let (storage, mut trie, root_idx) = if payload.trie_root == Felt::ZERO {
        Trie::create_empty(&conn)?
    } else {
        Trie::load_from_root(payload.trie_root, &conn)?
    };

    let leaf = TrieLeaf::new(payload.key, payload.value);
    trie.set(&storage, leaf.get_path(), leaf.data.value).map_err(MptError::from)?;

    let update = trie.commit(&storage).map_err(MptError::from)?;
    let trie_id = Trie::persist_updates(&storage, &update, &vec![leaf], Some(u64::from(root_idx)))?;

    Ok(Json(WriteResponse {
        trie_id: u64::from(trie_id),
        trie_root: update.root_commitment,
        key: leaf.key,
        value: leaf.data.value,
    }))
}
