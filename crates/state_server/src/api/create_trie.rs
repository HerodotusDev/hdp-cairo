use axum::{extract::State, Json};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};
use types::proofs::injected_state::leaf::TrieLeaf;

use crate::{
    mpt::{error::Error as MptError, trie::Trie},
    AppState,
};

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateTrieRequest {
    pub trie_label: Felt,
    pub keys: Vec<Felt>,
    pub values: Vec<Felt>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateTrieResponse {
    pub trie_root: Felt,
}

pub async fn create_trie(
    State(state): State<AppState>,
    Json(payload): Json<CreateTrieRequest>,
) -> Result<Json<CreateTrieResponse>, MptError> {
    let conn = state.get_connection(payload.trie_label)?;

    let (storage, mut trie, root_idx) = Trie::create_empty(&conn)?;

    let leaves = payload
        .keys
        .into_iter()
        .zip(payload.values.into_iter())
        .map(|(k, v)| TrieLeaf::new(k, v))
        .collect::<Vec<_>>();

    for leaf in &leaves {
        trie.set(&storage, leaf.get_path(), leaf.data.value)?;
    }

    let update = trie.commit(&storage)?;
    Trie::persist_updates(&storage, &update, &leaves, Some(u64::from(root_idx)))?;

    Ok(Json(CreateTrieResponse {
        trie_root: update.root_commitment,
    }))
}
