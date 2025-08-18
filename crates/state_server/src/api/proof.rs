use axum::{
    extract::{Query, State},
    Json,
};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use types::proofs::injected_state::{leaf::TrieLeaf, Action, StateProof, StateProofRead, StateProofWrite};

use crate::{mpt::trie::Trie, AppState};

#[derive(Serialize, Deserialize)]
pub struct GetStateProofsRequest {
    pub root_hash: Felt,
    pub actions: Vec<Action>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetStateProofsResponse {
    pub state_proofs: Vec<StateProof>,
}

pub async fn get_state_proofs(
    State(state): State<AppState>,
    Query(payload): Query<GetStateProofsRequest>,
) -> Result<Json<GetStateProofsResponse>, StatusCode> {
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut root_hash = payload.root_hash;
    let mut state_proofs = Vec::new();

    // Process each action
    for action in payload.actions.iter() {
        match action {
            Action::Read(action) => {
                let (storage, _trie, root_idx) = Trie::load_from_root(root_hash, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let leaf = match storage.get_leaf(action.key) {
                    Ok(leaf) => leaf,
                    Err(_) => TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
                };

                let proof = Trie::get_leaf_proof(&storage, root_hash, leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                state_proofs.push(StateProof::Read(StateProofRead {
                    trie_id: u64::from(root_idx),
                    state_proof: proof.into_iter().map(|(node, _)| node.into()).collect(),
                    root_hash,
                    leaf,
                }));
            }
            Action::Write(action) => {
                let (storage, mut trie, prev_root_idx) =
                    Trie::load_from_root(root_hash, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let pre_leaf = match storage.get_leaf(action.key) {
                    Ok(leaf) => leaf,
                    Err(_) => TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
                };
                let pre_proof = Trie::get_leaf_proof(&storage, root_hash, pre_leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let post_leaf = TrieLeaf::new(action.key, action.value);
                trie.set(&storage, post_leaf.get_path(), post_leaf.data.value)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                let update = trie.commit(&storage).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                let post_root_idx =
                    Trie::persist_updates(&storage, &update, &vec![post_leaf]).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let post_proof =
                    Trie::get_leaf_proof(&storage, update.root_commitment, post_leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                state_proofs.push(StateProof::Write(StateProofWrite {
                    trie_id_prev: u64::from(prev_root_idx),
                    root_hash_prev: root_hash,
                    state_proof_prev: pre_proof.into_iter().map(|(node, _)| node.into()).collect(),
                    leaf_prev: pre_leaf,
                    trie_id_post: u64::from(post_root_idx),
                    root_hash_post: update.root_commitment,
                    state_proof_post: post_proof.into_iter().map(|(node, _)| node.into()).collect(),
                    leaf_post: post_leaf,
                }));

                root_hash = update.root_commitment;
            }
        }
    }

    Ok(Json(GetStateProofsResponse { state_proofs }))
}
