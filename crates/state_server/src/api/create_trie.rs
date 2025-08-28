use axum::{extract::State, Json};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use types::proofs::injected_state::leaf::TrieLeaf;

use crate::{mpt::trie::Trie, AppState};

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
) -> Result<Json<CreateTrieResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (storage, mut trie, root_idx) = Trie::create_empty(&conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let leaves = payload
        .keys
        .into_iter()
        .zip(payload.values.into_iter())
        .map(|(k, v)| TrieLeaf::new(k, v))
        .collect::<Vec<_>>();

    for leaf in &leaves {
        trie.set(&storage, leaf.get_path(), leaf.data.value)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }

    let update = trie.commit(&storage).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Trie::persist_updates(&storage, &update, &leaves, Some(u64::from(root_idx)), payload.trie_label)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(CreateTrieResponse {
        trie_root: update.root_commitment,
    }))
}
