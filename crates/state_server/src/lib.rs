use std::{collections::HashMap, sync::Arc};

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use dashmap::DashMap;
use pathfinder_crypto::Felt;
use pathfinder_storage::{TrieStorageIndex, TrieUpdate};
use r2d2::PooledConnection;
use r2d2_sqlite::SqliteConnectionManager;
use serde::{Deserialize, Serialize};
use state_server_types::trie::leaf::{LeafData, TrieLeaf};
use tokio::net::TcpListener;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::info;

pub mod merkle_tree;

use pathfinder_common::hash::TruncatedKeccakHash;
use pathfinder_merkle_tree::tree::MerkleTree;
use trie_builder::{
    db::{trie::TrieDB, ConnectionManager},
    trie::Trie,
};
use types::proofs::state::{StateProof, StateProofWrapper, TrieNodeSerde};

#[derive(Debug, Clone)]
pub struct StateServerTrie {
    db_connection_manager: Arc<ConnectionManager>,
    pub root_hash: Felt,
    pub root_idx: TrieStorageIndex,
}

impl StateServerTrie {
    pub fn new(db_path: &str) -> anyhow::Result<Self> {
        let db_connection_manager = Arc::new(ConnectionManager::new(db_path));
        db_connection_manager.create_tables_if_not_exists()?;

        // Load storage
        let conn = db_connection_manager.get_connection()?;
        let storage = TrieDB::new(&conn);
        let root_idx: TrieStorageIndex = storage.get_node_idx().unwrap_or(0).into();
        let root_hash = storage.get_node_hash_by_idx(root_idx.into())?.unwrap_or(Felt::ZERO);

        Ok(Self {
            db_connection_manager,
            root_hash,
            root_idx,
        })
    }

    pub fn get_key(&self, key: Felt) -> Option<Felt> {
        let conn = self.db_connection_manager.get_connection().unwrap();
        let (storage, _) = self.get_storage_and_trie(&conn);
        match storage.get_leaf(key) {
            Ok(leaf) => {
                if leaf.is_empty() {
                    return None;
                }
                Some(leaf.data.value)
            }
            Err(_) => None,
        }
    }

    fn get_storage_and_trie<'a>(
        &self,
        conn: &'a PooledConnection<SqliteConnectionManager>,
    ) -> (TrieDB<'a>, MerkleTree<TruncatedKeccakHash, 251>) {
        let storage = TrieDB::new(conn);

        if self.root_idx == TrieStorageIndex::from(0) {
            // Empty trie
            (storage, MerkleTree::<TruncatedKeccakHash, 251>::empty())
        } else {
            // Load existing trie
            let (_, trie) = Trie::load(self.root_idx, conn);
            (storage, trie)
        }
    }

    fn insert(&mut self, key: Felt, value: Felt) -> anyhow::Result<TrieUpdate> {
        // Create a new leaf with the key-value pair
        let leaf = TrieLeaf::new(key, value);

        let conn = self.db_connection_manager.get_connection()?;
        let (storage, mut trie) = self.get_storage_and_trie(&conn);

        // Set the leaf in the trie
        trie.set(&storage, leaf.get_path(), leaf.commitment())?;
        let update = trie.commit(&storage).unwrap();
        let new_root_idx = Trie::persist_updates(&storage, &update, &vec![leaf])?;

        // Update local root_idx and root_hash
        self.root_idx = new_root_idx;
        self.root_hash = update.root_commitment;

        Ok(update)
    }
}

type TrieId = Felt;
type TrieStorage = Arc<DashMap<TrieId, StateServerTrie>>;

// API request/response types
#[derive(Deserialize)]
pub struct NewTrieRequest {
    id: Option<Felt>,
}

#[derive(Serialize, Deserialize)]
pub struct GetStateProofsRequest {
    pub actions: Vec<String>, // Action strings in serialized format
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateProofResult {
    pub action: types::actions::action::Action,
    pub proof: StateProofWrapper,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GetStateProofsResponse {
    pub results: Vec<StateProofResult>,
}

// Application state
#[derive(Clone)]
pub struct AppState {
    pub tries: TrieStorage,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            tries: Arc::new(DashMap::new()),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Deserialize, Serialize)]
pub struct InsertInitialDataRequest {
    trie_id: Felt,
    keys: Vec<Felt>,
    values: Vec<Felt>,
}

#[derive(Deserialize)]
pub struct GetKeyParams {
    key: Felt,
}

// API handlers
async fn new_trie(State(state): State<AppState>, Json(payload): Json<NewTrieRequest>) -> Result<Json<serde_json::Value>, StatusCode> {
    if payload.id.is_none() {
        return Err(StatusCode::BAD_REQUEST);
    }

    let trie_id = payload.id.unwrap();
    let db_path = format!("/tmp/{}.db", trie_id.to_hex_str());

    let trie = StateServerTrie::new(&db_path).map_err(|_e| StatusCode::INTERNAL_SERVER_ERROR)?;
    let root_hash = trie.root_hash;

    state.tries.insert(trie_id, trie);

    Ok(Json(serde_json::json!({
        "trie_id": trie_id,
        "root_hash": root_hash,
    })))
}

async fn get_key(
    State(state): State<AppState>,
    Path(trie_id): Path<Felt>,
    Query(params): Query<GetKeyParams>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let state_trie = state.tries.get(&trie_id).ok_or(StatusCode::NOT_FOUND)?;
    let value = state_trie.get_key(params.key).ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(serde_json::json!({
        "trie_id": trie_id,
        "key": params.key,
        "value": value,
    })))
}

pub async fn insert_initial_data(
    State(state): State<AppState>,
    Json(payload): Json<InsertInitialDataRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut state_trie = state.tries.get_mut(&payload.trie_id).ok_or(StatusCode::NOT_FOUND)?;

    for (key, value) in payload.keys.iter().zip(payload.values.iter()).take(50) {
        state_trie.insert(*key, *value).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }

    Ok(Json(serde_json::json!({
        "trie_id": payload.trie_id,
        "root_hash": state_trie.root_hash,
    })))
}

async fn get_root_hash(State(state): State<AppState>, Path(trie_id): Path<Felt>) -> Result<Json<serde_json::Value>, StatusCode> {
    let state_trie = state.tries.get(&trie_id).ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(serde_json::json!({
        "trie_id": trie_id,
        "root_idx": u64::from(state_trie.root_idx),
        "root_hash": state_trie.root_hash,
    })))
}

async fn get_state_proofs(
    State(mut state): State<AppState>,
    Json(payload): Json<GetStateProofsRequest>,
) -> Result<Json<GetStateProofsResponse>, StatusCode> {
    // Parse actions
    let actions: Vec<types::actions::action::Action> = match payload
        .actions
        .iter()
        .map(|action| types::actions::action::Action::deserialize(action.as_str()))
        .collect::<Result<Vec<types::actions::action::Action>, _>>()
    {
        Ok(actions) => actions,
        Err(_) => return Err(StatusCode::BAD_REQUEST),
    };

    // Initialize cur_roots for tracking state changes within this request
    let mut cur_roots = HashMap::<Felt, Felt>::new();
    let trie_ids: Vec<Felt> = actions.iter().map(|action| action.root_hash).collect();

    // Store original roots
    let mut original_roots = HashMap::<Felt, (Felt, TrieStorageIndex)>::new();
    for trie_id in &trie_ids {
        ensure_trie_exists(&mut state, trie_id, &mut cur_roots, &mut original_roots).map_err(|_| StatusCode::NOT_FOUND)?;
    }

    let mut results = Vec::new();

    // Process each action
    for action in actions.iter() {
        let trie_id = action.root_hash;

        // Process the action
        let proof = if let Some(mut trie) = state.tries.get_mut(&trie_id) {
            match action.action_type {
                types::actions::action::ActionType::Read => handle_read_action(&trie, action, &trie_id, &cur_roots)?,
                types::actions::action::ActionType::Write => handle_write_action(&mut trie, action, &trie_id, &mut cur_roots)?,
            }
        } else {
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        };

        results.push(StateProofResult {
            action: action.clone(),
            proof,
        });
    }

    // Iterate on results proofs leafs and delete them from the trie
    for result in results.clone() {
        if let Some(leaf) = result.proof.post_proof_leaf {
            let conn = &state
                .tries
                .get(&result.proof.trie_id)
                .unwrap()
                .db_connection_manager
                .get_connection()
                .unwrap();
            if let Some(trie) = state.tries.get(&result.proof.trie_id) {
                let (storage, mut merkle_trie) = Trie::load(trie.root_idx, conn);
                merkle_trie.set(&storage, leaf.get_path(), pathfinder_crypto::Felt::ZERO).unwrap();
                storage.delete_leaf(leaf.key).unwrap();
            }
        }
    }

    // Revert all tries to their original roots
    for (trie_id, (original_root_hash, original_root_idx)) in original_roots {
        if let Some(mut trie) = state.tries.get_mut(&trie_id) {
            trie.root_hash = original_root_hash;
            trie.root_idx = original_root_idx;
        }
    }

    Ok(Json(GetStateProofsResponse { results }))
}

// Helper function to ensure a trie exists, creating it if necessary
fn ensure_trie_exists(
    state: &mut AppState,
    trie_id: &Felt,
    cur_roots: &mut HashMap<Felt, Felt>,
    original_roots: &mut HashMap<Felt, (Felt, TrieStorageIndex)>,
) -> Result<(), String> {
    if !state.tries.contains_key(trie_id) {
        let db_path = format!("/tmp/{}.db", trie_id);
        match StateServerTrie::new(&db_path) {
            Ok(new_trie) => {
                cur_roots.insert(*trie_id, new_trie.root_hash);
                original_roots.insert(*trie_id, (new_trie.root_hash, new_trie.root_idx));
                state.tries.insert(*trie_id, new_trie);
                Ok(())
            }
            Err(e) => Err(format!("Failed to create trie {}: {}", trie_id, e)),
        }
    } else {
        let trie = state.tries.get(trie_id).unwrap();
        cur_roots.insert(*trie_id, trie.root_hash);
        original_roots.insert(*trie_id, (trie.root_hash, trie.root_idx));
        Ok(())
    }
}

// Helper function to handle Read actions
fn handle_read_action(
    trie: &StateServerTrie,
    action: &types::actions::action::Action,
    trie_id: &Felt,
    cur_roots: &HashMap<Felt, Felt>,
) -> Result<StateProofWrapper, StatusCode> {
    let conn = &trie
        .db_connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Get the current root hash for this trie
    let current_root = match cur_roots.get(&trie_id) {
        Some(root) => *root,
        None => return Err(StatusCode::INTERNAL_SERVER_ERROR),
    };

    // Handle empty trie case
    if current_root == pathfinder_crypto::Felt::ZERO {
        return Ok(StateProofWrapper {
            trie_id: *trie_id,
            state_proof: StateProof::NonInclusion(vec![]),
            root_hash: pathfinder_crypto::Felt::ZERO,
            leaf: TrieLeaf {
                key: action.key,
                data: LeafData {
                    value: pathfinder_crypto::Felt::ZERO,
                },
            },
            post_proof_root_hash: None,
            post_proof_leaf: None,
        });
    }

    let (db, _) = Trie::load(trie.root_idx, conn);
    // Retrieve leaf from db
    let leaf = match db.get_leaf(action.key) {
        Ok(leaf) => leaf,
        Err(_) => TrieLeaf::new(action.key, pathfinder_crypto::Felt::ZERO),
    };

    match Trie::get_leaf_proof(&db, current_root, leaf) {
        Ok(trie_proof) => {
            let key_exists = db
                .get_leaf(action.key)
                .map(|stored_value| stored_value.data.value != pathfinder_crypto::Felt::ZERO)
                .unwrap_or(false);

            let proof_nodes: Vec<TrieNodeSerde> = trie_proof.into_iter().map(|(node, _)| node.into()).collect();

            if key_exists {
                Ok(StateProofWrapper {
                    trie_id: *trie_id,
                    state_proof: StateProof::Inclusion(proof_nodes),
                    root_hash: current_root,
                    leaf,
                    post_proof_root_hash: None,
                    post_proof_leaf: None,
                })
            } else {
                Ok(StateProofWrapper {
                    trie_id: *trie_id,
                    state_proof: StateProof::NonInclusion(proof_nodes),
                    root_hash: current_root,
                    leaf,
                    post_proof_root_hash: None,
                    post_proof_leaf: None,
                })
            }
        }
        Err(_) => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}

// Helper function to generate a local leaf proof
fn generate_local_leaf_proof(
    storage: &TrieDB,
    cur_roots: &HashMap<Felt, Felt>,
    trie_id: &Felt,
    leaf: TrieLeaf,
) -> Result<Vec<(TrieNodeSerde, pathfinder_crypto::Felt)>, StatusCode> {
    let current_root = *cur_roots.get(trie_id).unwrap();

    if current_root == pathfinder_crypto::Felt::ZERO {
        // Empty trie - no proof
        Ok(vec![])
    } else {
        let proof = Trie::get_leaf_proof(storage, current_root, leaf).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        Ok(proof.into_iter().map(|(node, _)| (node.into(), leaf.data.value)).collect())
    }
}

// Helper function to handle Write actions
fn handle_write_action(
    trie: &mut StateServerTrie,
    action: &types::actions::action::Action,
    trie_id: &Felt,
    cur_roots: &mut HashMap<Felt, Felt>,
) -> Result<StateProofWrapper, StatusCode> {
    let conn = &trie
        .db_connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Handle both empty and non-empty tries by actually executing the write
    let (storage, mut merkle_trie) = if trie.root_hash == pathfinder_crypto::Felt::ZERO {
        // Empty trie - start fresh
        (TrieDB::new(conn), MerkleTree::<TruncatedKeccakHash, 251>::empty())
    } else {
        // Load existing trie
        Trie::load(trie.root_idx, conn)
    };

    // Get pre-proof
    let pre_proof_leaf = storage.get_leaf(action.key).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let pre_proof = generate_local_leaf_proof(&storage, cur_roots, trie_id, pre_proof_leaf)?;
    let pre_proof_root_hash = *cur_roots.get(trie_id).unwrap();

    let leaf = TrieLeaf::new(action.key, action.value.unwrap_or(pathfinder_crypto::Felt::ZERO));
    let key = leaf.get_path();

    // Execute the write operation
    merkle_trie
        .set(&storage, key.clone(), leaf.commitment())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Commit and persist the changes to get valid proof
    match merkle_trie.commit(&storage) {
        Ok(update) => {
            let new_root = update.root_commitment;

            // Persist changes to get valid proof
            let new_root_idx = match Trie::persist_updates(&storage, &update, &vec![leaf]) {
                Ok(idx) => idx,
                Err(_) => return Err(StatusCode::INTERNAL_SERVER_ERROR),
            };
            trie.root_idx = new_root_idx;
            trie.root_hash = new_root;

            // Update cur_roots for subsequent actions in this request
            cur_roots.insert(*trie_id, new_root);

            // Generate post-proof
            let post_proof = generate_local_leaf_proof(&storage, cur_roots, trie_id, leaf)?;

            // Don't allow empty proofs for both pre and post unless it's a first write to empty trie
            if pre_proof.is_empty() && post_proof.is_empty() && trie.root_hash != pathfinder_crypto::Felt::ZERO {
                return Err(StatusCode::INTERNAL_SERVER_ERROR);
            }

            Ok(StateProofWrapper {
                trie_id: *trie_id,
                state_proof: StateProof::Update((
                    pre_proof.into_iter().map(|(node, _)| node).collect(),
                    post_proof.into_iter().map(|(node, _)| node).collect(),
                )),
                root_hash: pre_proof_root_hash,
                leaf: pre_proof_leaf,
                post_proof_root_hash: Some(new_root),
                post_proof_leaf: Some(leaf),
            })
        }
        Err(_) => Err(StatusCode::INTERNAL_SERVER_ERROR),
    }
}

// Router setup
pub fn create_router() -> Router {
    let state = AppState::new();

    Router::new()
        .route("/new-trie", post(new_trie))
        .route("/get-state-proofs", post(get_state_proofs))
        .route("/insert-initial-data", post(insert_initial_data))
        .route("/get-key/:trie_id", get(get_key))
        .route("/get-root-hash/:trie_id", get(get_root_hash))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

// Server startup
pub async fn start_server(port: u16) -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();

    let app = create_router();
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;

    info!("State server listening on {}", addr);
    info!("Available endpoints:");
    info!("  POST /new-trie - Create a new trie");
    info!("  POST /insert-initial-data - Insert initial data into a trie");
    info!("  GET /get-root-hash/{{trie_id}} - Get root hash of a trie");
    info!("  GET /get-key/{{trie_id}}?key=<key> - Get value of a key");
    info!("  GET /get-state-proofs - Generate structured StateProof objects for actions (read=inclusion|non-inclusion, write=update)");

    axum::serve(listener, app).await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use pathfinder_common::trie::TrieNode;
    use pathfinder_crypto::Felt;
    use tower::util::ServiceExt;
    use trie_builder::trie::Membership;

    use super::*;

    fn build_request_new_trie(trie_id: &Felt) -> Request<Body> {
        Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id.to_hex_str())))
            .unwrap()
    }

    fn build_request_insert_initial_data(trie_id: &Felt, keys: &[Felt], values: &[Felt]) -> Request<Body> {
        let body = serde_json::json!({
            "trie_id": trie_id.to_hex_str(),
            "keys": keys,
            "values": values
        });
        Request::builder()
            .method("POST")
            .uri("/insert-initial-data")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_string(&body).unwrap()))
            .unwrap()
    }

    #[tokio::test]
    async fn test_new_trie_with_id() {
        let app = create_router();
        let trie_id = Felt::random(&mut rand::thread_rng());

        let response = app.oneshot(build_request_new_trie(&trie_id)).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();

        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: serde_json::Value = serde_json::from_str(&response_text).unwrap();

        assert_eq!(response_body["trie_id"].as_str().unwrap(), trie_id.to_hex_str());
        assert!(!response_body["root_hash"].is_null());
        assert!(response_body["root_hash"].is_string());
    }

    #[tokio::test]
    async fn test_get_state_proofs_read_only() {
        use tower::{util::ServiceExt, Service};

        let mut app = create_router();

        let trie_id = Felt::random(&mut rand::thread_rng());
        let response = app.clone().oneshot(build_request_new_trie(&trie_id)).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let keys = vec![
            Felt::from_u128(120368059344249),
            Felt::from_u128(42),
            Felt::from_u128(100000000000000),
        ];
        let values = vec![Felt::from_u128(555), Felt::from_u128(777), Felt::from_u128(999)];

        let response = app
            .clone()
            .oneshot(build_request_insert_initial_data(&trie_id, &keys, &values))
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let combined_actions = vec![
            // Read existing keys
            format!("{};0;{}", trie_id, keys[0].to_hex_str()),
            format!("{};0;{}", trie_id, keys[1].to_hex_str()),
            format!("{};0;{}", trie_id, keys[2].to_hex_str()),
            // Read non-existing key
            format!("{};0;{}", trie_id, Felt::from_u128(999999999999999).to_hex_str()),
        ];

        let request_payload = GetStateProofsRequest {
            actions: combined_actions.clone(),
        };

        let request = Request::builder()
            .method("POST")
            .uri("/get-state-proofs")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_string(&request_payload).unwrap()))
            .unwrap();

        let response = ServiceExt::<Request<Body>>::ready(&mut app)
            .await
            .unwrap()
            .call(request)
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: GetStateProofsResponse = serde_json::from_str(&response_text).unwrap();

        // Verify all proofs
        for (i, proof) in response_body.results.iter().enumerate() {
            let (key, value) = if i < 3 {
                (keys[i], values[i])
            } else if i == 3 {
                (Felt::from_u128(999999999999999), Felt::ZERO) // Non-existing
            } else {
                panic!("Unexpected proof index")
            };
            let leaf = TrieLeaf::new(key, value);

            match &proof.proof.state_proof {
                StateProof::Inclusion(trie_nodes) | StateProof::NonInclusion(trie_nodes) => {
                    let trie_node: Vec<TrieNode> = trie_nodes.iter().map(|node| node.clone().into()).collect();
                    let p: Vec<(TrieNode, Felt)> = trie_node.into_iter().map(|node| (node, Felt::ZERO)).collect();

                    let proof_result = Trie::verify_proof(&p, proof.proof.root_hash, leaf);
                    match proof_result {
                        Some(Membership::Member) if i != 3 => {
                            assert!(true);
                        }
                        Some(Membership::NonMember) if i == 3 => {
                            assert!(true);
                        }
                        Some(Membership::NonMember) => {
                            assert!(false);
                        }
                        Some(Membership::Member) => {
                            assert!(false);
                        }
                        None => {
                            assert!(false);
                        }
                    }
                }
                _ => {
                    panic!("Unexpected proof type for proof {}", i);
                }
            }
        }
    }

    fn build_request_get_key(trie_id: &Felt, key: &Felt) -> Request<Body> {
        Request::builder()
            .method("GET")
            .uri(format!("/get-key/{}?key={}", trie_id.to_hex_str(), key.to_hex_str()))
            .body(Body::from(""))
            .unwrap()
    }

    #[tokio::test]
    async fn test_get_state_proofs_read_write() {
        use tower::{util::ServiceExt, Service};

        let mut app = create_router();

        let trie_id = Felt::random(&mut rand::thread_rng());

        let keys = vec![
            Felt::from_u128(120368059344249),
            Felt::from_u128(42),
            Felt::from_u128(100000000000000),
        ];
        let values = vec![Felt::from_u128(555), Felt::from_u128(777), Felt::from_u128(999)];

        let combined_actions = vec![
            // Write existing keys
            format!("{};1;{};{}", trie_id, keys[0].to_hex_str(), values[0].to_hex_str()),
            format!("{};1;{};{}", trie_id, keys[1].to_hex_str(), values[1].to_hex_str()),
            format!("{};1;{};{}", trie_id, keys[2].to_hex_str(), values[2].to_hex_str()),
            // Read existing keys
            format!("{};0;{}", trie_id, keys[0].to_hex_str()),
            format!("{};0;{}", trie_id, keys[1].to_hex_str()),
            format!("{};0;{}", trie_id, keys[2].to_hex_str()),
            // Read non-existing key
            format!("{};0;{}", trie_id, Felt::from_u128(999999999999999).to_hex_str()),
            // Overwrite 42 key
            format!("{};1;{};{}", trie_id, keys[1].to_hex_str(), values[1].to_hex_str()),
        ];

        let request_payload = GetStateProofsRequest {
            actions: combined_actions.clone(),
        };

        let request = Request::builder()
            .method("POST")
            .uri("/get-state-proofs")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_string(&request_payload).unwrap()))
            .unwrap();

        let response = ServiceExt::<Request<Body>>::ready(&mut app)
            .await
            .unwrap()
            .call(request)
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: GetStateProofsResponse = serde_json::from_str(&response_text).unwrap();

        // Verify all proofs
        for (i, proof) in response_body.results.iter().enumerate() {
            let keys = keys.clone();
            let key = if i == 6 {
                Felt::from_u128(999999999999999) // Non-existing
            } else {
                let key_idx = match i {
                    0..=2 => i,
                    3..=5 => i - 3,
                    7 => 1,
                    _ => panic!("Unexpected proof index"),
                };
                keys[key_idx].clone()
            };

            let value = if i == 6 {
                Felt::ZERO // Non-existing
            } else {
                let value_idx = match i {
                    0..=2 => i,
                    3..=5 => i - 3,
                    7 => 1,
                    _ => panic!("Unexpected proof index"),
                };
                values[value_idx]
            };
            let leaf = TrieLeaf::new(key, value);

            match &proof.proof.state_proof {
                StateProof::Inclusion(trie_nodes) | StateProof::NonInclusion(trie_nodes) => {
                    let trie_node: Vec<TrieNode> = trie_nodes.iter().map(|node| node.clone().into()).collect();
                    let p: Vec<(TrieNode, Felt)> = trie_node.into_iter().map(|node| (node, Felt::ZERO)).collect();
                    let proof_result = Trie::verify_proof(&p, proof.proof.root_hash, leaf);
                    match proof_result {
                        Some(Membership::Member) if i != 6 => {
                            assert!(true);
                        }
                        Some(Membership::NonMember) if i == 6 => {
                            assert!(true);
                        }
                        Some(Membership::NonMember) => {
                            assert!(false);
                        }
                        Some(Membership::Member) => {
                            assert!(false);
                        }
                        None => {
                            assert!(false);
                        }
                    }
                }
                StateProof::Update((pre_proof, post_proof)) => {
                    if pre_proof.len() == 0 {
                        assert!(true);
                        continue;
                    }

                    let p1: Vec<TrieNode> = pre_proof.iter().map(|node| node.clone().into()).collect();
                    let p1: Vec<(TrieNode, Felt)> = p1.into_iter().map(|node| (node, Felt::ZERO)).collect();
                    let pre_proof_result = Trie::verify_proof(&p1, proof.proof.root_hash, proof.proof.leaf);

                    assert!(pre_proof_result.is_some());

                    let p2: Vec<TrieNode> = post_proof.iter().map(|node| node.clone().into()).collect();
                    let p2: Vec<(TrieNode, Felt)> = p2.into_iter().map(|node| (node, Felt::ZERO)).collect();

                    let post_proof_result =
                        Trie::verify_proof(&p2, proof.proof.post_proof_root_hash.unwrap(), proof.proof.post_proof_leaf.unwrap());

                    assert!(post_proof_result.is_some());
                }
            }

            // Check that all keys have been deleted by calling get-key on each
            for key in keys {
                let response = app.clone().oneshot(build_request_get_key(&trie_id, &key)).await.unwrap();
                assert_eq!(response.status(), StatusCode::NOT_FOUND);
            }
        }
    }

    #[tokio::test]
    async fn test_get_state_proofs_from_dry_run_output() {
        use tower::{util::ServiceExt, Service};

        let mut app = create_router();

        let trie_id = Felt::random(&mut rand::thread_rng());

        let keys = vec![
            Felt::from_u128(120368059344249),
            Felt::from_u128(42),
            Felt::from_u128(100000000000000),
        ];
        let values = vec![Felt::from_u128(555), Felt::from_u128(777), Felt::from_u128(999)];

        let combined_actions = vec![
            format!("{};1;{};{}", trie_id, keys[0].to_hex_str(), values[0].to_hex_str()),
            format!("{};0;{}", trie_id, keys[0].to_hex_str()),
            format!("{};0;{}", trie_id, keys[0].to_hex_str()),
            format!("{};0;{}", trie_id, keys[1].to_hex_str()),
            format!("{};1;{};{}", trie_id, keys[0].to_hex_str(), values[0].to_hex_str()),
            format!("{};0;{}", trie_id, keys[0].to_hex_str()),
        ];

        let request_payload = GetStateProofsRequest {
            actions: combined_actions.clone(),
        };

        let request = Request::builder()
            .method("POST")
            .uri("/get-state-proofs")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_string(&request_payload).unwrap()))
            .unwrap();

        let response = ServiceExt::<Request<Body>>::ready(&mut app)
            .await
            .unwrap()
            .call(request)
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: GetStateProofsResponse = serde_json::from_str(&response_text).unwrap();

        println!("Response body: {:?}", response_body);
    }
}
