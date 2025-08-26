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
    let conn = state
        .connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut state_proofs = Vec::new();

    // Process each action
    for action in payload.actions.iter() {
        match action {
            Action::Read(action) => {
                // Handle empty root case
                if action.trie_root == Felt::ZERO {
                    state_proofs.push(StateProof::Read(StateProofRead {
                        trie_id: 0,
                        state_proof: vec![],
                        trie_root: action.trie_root,
                        leaf: TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
                    }));
                    continue;
                }

                let (storage, _trie, root_idx) =
                    Trie::load_from_root(action.trie_root, &action.trie_label, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let leaf = match storage.get_leaf(action.key, u64::from(root_idx), &action.trie_label) {
                    Ok(leaf) => leaf,
                    Err(_) => TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
                };

                let proof = Trie::get_leaf_proof(&storage, action.trie_root, leaf, &action.trie_label)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                state_proofs.push(StateProof::Read(StateProofRead {
                    trie_id: u64::from(root_idx),
                    state_proof: proof.into_iter().map(|(node, _)| node.into()).collect(),
                    trie_root: action.trie_root,
                    leaf,
                }));
            }
            Action::Write(action) => {
                let (storage, mut trie, prev_root_idx) = if action.trie_root == Felt::ZERO {
                    Trie::create_empty(&conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                } else {
                    Trie::load_from_root(action.trie_root, &action.trie_label, &conn).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                };

                let pre_leaf = match storage.get_leaf(action.key, u64::from(prev_root_idx), &action.trie_label) {
                    Ok(leaf) => leaf,
                    Err(_) => TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
                };
                let pre_proof = if action.trie_root == Felt::ZERO {
                    vec![]
                } else {
                    Trie::get_leaf_proof(&storage, action.trie_root, pre_leaf, &action.trie_label)
                        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
                };

                let post_leaf = TrieLeaf::new(action.key, action.value);
                trie.set(&storage, post_leaf.get_path(), post_leaf.data.value)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                let update = trie.commit(&storage).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let post_root_idx = storage
                    .get_node_idx_by_hash(update.root_commitment, &action.trie_label)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                let post_proof = Trie::get_leaf_proof(&storage, update.root_commitment, post_leaf, &action.trie_label)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                state_proofs.push(StateProof::Write(StateProofWrite {
                    trie_id_prev: u64::from(prev_root_idx),
                    trie_root_prev: action.trie_root,
                    state_proof_prev: pre_proof.into_iter().map(|(node, _)| node.into()).collect(),
                    leaf_prev: pre_leaf,
                    trie_id_post: post_root_idx.expect("Could not infer post root idx"),
                    trie_root_post: update.root_commitment,
                    state_proof_post: post_proof.into_iter().map(|(node, _)| node.into()).collect(),
                    leaf_post: post_leaf,
                }));
            }
        }
    }

    Ok(Json(GetStateProofsResponse { state_proofs }))
}
