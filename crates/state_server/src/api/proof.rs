use axum::{extract::State, Json};
use pathfinder_crypto::Felt;
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use types::proofs::injected_state::{leaf::TrieLeaf, Action, StateProof, StateProofRead, StateProofWrite};

use crate::{mpt::trie::Trie, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct GetStateProofsRequest {
    pub actions: Vec<Action>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetStateProofsResponse {
    pub state_proofs: Vec<StateProof>,
}

pub async fn get_state_proofs(
    State(state): State<AppState>,
    Json(payload): Json<GetStateProofsRequest>,
) -> Result<Json<GetStateProofsResponse>, StatusCode> {
    // Early return if no actions
    if payload.actions.is_empty() {
        return Ok(Json(GetStateProofsResponse { state_proofs: vec![] }));
    }

    let mut state_proofs = Vec::new();

    // Process each action
    for action in payload.actions.iter() {
        match action {
            Action::Read(action) => {
                // Handle empty root case
                if action.trie_root == Felt::ZERO {
                    state_proofs.push(StateProof::Read(StateProofRead {
                        trie_label: action.trie_label,
                        state_proof: vec![],
                        trie_root: action.trie_root,
                        leaf: TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
                    }));
                    continue;
                }

                let conn = state
                    .get_connection(action.trie_label)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let (mut storage, _trie, root_idx) =
                    Trie::load_from_root(action.trie_root, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                storage.max_root_idx = u64::from(root_idx);
                let leaf = storage
                    .get_leaf_at(action.key, u64::from(root_idx))
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                    .unwrap_or(TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO));

                let (mut storage, _trie, root_idx) =
                    Trie::load_from_root(action.trie_root, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                storage.max_root_idx = u64::from(root_idx);
                let proof = Trie::get_leaf_proof(&storage, action.trie_root, leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                state_proofs.push(StateProof::Read(StateProofRead {
                    trie_label: action.trie_label,
                    state_proof: proof.into_iter().map(|(node, _)| node.into()).collect(),
                    trie_root: action.trie_root,
                    leaf,
                }));
            }
            Action::Write(action) => {
                let conn = state
                    .get_connection(action.trie_label)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let (mut storage, mut trie, prev_root_idx) = if action.trie_root == Felt::ZERO {
                    Trie::create_empty(&conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                } else {
                    Trie::load_from_root(action.trie_root, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                };

                storage.max_root_idx = u64::from(prev_root_idx);
                let pre_leaf = storage
                    .get_leaf_at(action.key, u64::from(prev_root_idx))
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                    .unwrap_or(TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO));

                let pre_proof = if action.trie_root == Felt::ZERO {
                    vec![]
                } else {
                    Trie::get_leaf_proof(&storage, action.trie_root, pre_leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                };

                let post_leaf = TrieLeaf::new(action.key, action.value);
                trie.set(&storage, post_leaf.get_path(), post_leaf.data.value)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                let update = trie.commit(&storage).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let post_root_idx = storage
                    .get_node_idx_by_hash(update.root_commitment)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                storage.max_root_idx = post_root_idx.expect("Could not infer post root idx");

                let post_proof =
                    Trie::get_leaf_proof(&storage, update.root_commitment, post_leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                state_proofs.push(StateProof::Write(StateProofWrite {
                    trie_label: action.trie_label,
                    trie_root_prev: action.trie_root,
                    state_proof_prev: pre_proof.into_iter().map(|(node, _)| node.into()).collect(),
                    leaf_prev: pre_leaf,
                    trie_root_post: update.root_commitment,
                    state_proof_post: post_proof.into_iter().map(|(node, _)| node.into()).collect(),
                    leaf_post: post_leaf,
                }));
            }
        }
    }

    Ok(Json(GetStateProofsResponse { state_proofs }))
}
