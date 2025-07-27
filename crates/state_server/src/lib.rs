use std::{collections::HashMap, sync::Arc};

use anyhow::anyhow;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use dashmap::DashMap;
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
    pub root_hash: pathfinder_crypto::Felt,
    pub root_idx: pathfinder_storage::TrieStorageIndex,
}

impl StateServerTrie {
    pub fn new(db_path: &str) -> anyhow::Result<Self> {
        let db_connection_manager = Arc::new(ConnectionManager::new(db_path));
        db_connection_manager.create_tables_if_not_exists()?;

        // Load storage
        let conn = db_connection_manager.get_connection()?;
        let storage = TrieDB::new(&conn);
        let root_idx: TrieStorageIndex = storage.get_node_idx().unwrap_or(0).into();
        let root_hash = storage
            .get_node_hash_by_idx(root_idx.into())?
            .unwrap_or(pathfinder_crypto::Felt::ZERO);

        Ok(Self {
            db_connection_manager,
            root_hash,
            root_idx,
        })
    }

    pub fn get_key(&self, key: &str) -> Option<String> {
        let conn = self.db_connection_manager.get_connection().unwrap();
        let (storage, _) = self.get_storage_and_trie(&conn);
        match storage.get_leaf(self.string_to_felt(key).unwrap()) {
            Ok(leaf) => {
                if leaf.is_empty() {
                    return None;
                }
                Some(leaf.data.value.to_string())
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

    fn insert(&mut self, key: String, value: String) -> anyhow::Result<TrieUpdate> {
        // Validate inputs
        if key.is_empty() || value.is_empty() {
            return Err(anyhow!("Key and value cannot be empty"));
        }

        // Convert key and value to Felt
        let key_felt = self.string_to_felt(&key)?;
        let value_felt = self.string_to_felt(&value)?;

        // Create a new leaf with the key-value pair
        let leaf = TrieLeaf::new(key_felt, value_felt);

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

    // Helper function to convert a string to a Felt
    fn string_to_felt(&self, s: &str) -> anyhow::Result<pathfinder_crypto::Felt> {
        if s.starts_with("0x") || s.starts_with("0X") {
            pathfinder_crypto::Felt::from_hex_str(s).map_err(|e| anyhow!("Invalid hex string: {}", e))
        } else {
            let num = s.parse::<u64>()?;
            Ok(pathfinder_crypto::Felt::from(num))
        }
    }
}

type TrieId = String;
type TrieStorage = Arc<DashMap<TrieId, StateServerTrie>>;

// API request/response types
#[derive(Deserialize)]
pub struct NewTrieRequest {
    id: Option<String>,
}

#[derive(Serialize, Deserialize)]
pub struct GetStateProofsRequest {
    pub actions: Vec<String>, // Action strings in serialized format
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct StateProofResult {
    pub action: String, // Action string in serialized format
    pub proof: StateProofWrapper,
}

#[derive(Serialize, Deserialize, Debug)]
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
    trie_id: String,
    keys: Vec<String>,
    values: Vec<String>,
}

#[derive(Deserialize)]
pub struct GetKeyParams {
    key: String,
}

// API handlers
async fn new_trie(State(state): State<AppState>, Json(payload): Json<NewTrieRequest>) -> Result<Json<serde_json::Value>, StatusCode> {
    let trie_id = payload.id.unwrap_or_else(|| format!("trie_{}", uuid::Uuid::new_v4()));
    let db_path = format!("/tmp/{}.db", trie_id);

    let trie = StateServerTrie::new(&db_path).map_err(|_e| StatusCode::INTERNAL_SERVER_ERROR)?;
    let root_hash = trie.root_hash;

    state.tries.insert(trie_id.clone(), trie);

    Ok(Json(serde_json::json!({
        "trie_id": trie_id,
        "root_hash": root_hash,
    })))
}

async fn get_key(
    State(state): State<AppState>,
    Path(trie_id): Path<String>,
    Query(params): Query<GetKeyParams>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let state_trie = state.tries.get(&trie_id).ok_or(StatusCode::NOT_FOUND)?;
    let value = state_trie.get_key(&params.key).ok_or(StatusCode::NOT_FOUND)?;

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
        state_trie
            .insert(key.clone(), value.clone())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }

    Ok(Json(serde_json::json!({
        "trie_id": payload.trie_id,
        "root_hash": state_trie.root_hash,
    })))
}

async fn get_root_hash(State(state): State<AppState>, Path(trie_id): Path<String>) -> Result<Json<serde_json::Value>, StatusCode> {
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
    let actions: Vec<dry_hint_processor::syscall_handler::injected_state::Action> = match payload
        .actions
        .iter()
        .map(|action| dry_hint_processor::syscall_handler::injected_state::Action::deserialize(action.as_str()))
        .collect::<Result<Vec<dry_hint_processor::syscall_handler::injected_state::Action>, _>>()
    {
        Ok(actions) => actions,
        Err(_) => return Err(StatusCode::BAD_REQUEST),
    };

    // Initialize cur_roots for tracking state changes within this request
    let mut cur_roots = HashMap::<String, pathfinder_crypto::Felt>::new();
    let trie_ids: Vec<String> = actions.iter().map(|action| action.root_hash.clone()).collect();

    // Store original roots
    let mut original_roots = HashMap::<String, (pathfinder_crypto::Felt, TrieStorageIndex)>::new();
    for trie_id in &trie_ids {
        ensure_trie_exists(&mut state, trie_id, &mut cur_roots, &mut original_roots).map_err(|_| StatusCode::NOT_FOUND)?;
    }

    let mut results = Vec::new();

    // Process each action
    for (idx, action) in actions.iter().enumerate() {
        let trie_id = action.root_hash.clone();

        // Process the action
        let proof = if let Some(mut trie) = state.tries.get_mut(&trie_id) {
            match action.action_type {
                dry_hint_processor::syscall_handler::injected_state::ActionType::Read => {
                    handle_read_action(&trie, action, &trie_id, &cur_roots)?
                }
                dry_hint_processor::syscall_handler::injected_state::ActionType::Write => {
                    handle_write_action(&mut trie, action, &trie_id, &mut cur_roots)?
                }
            }
        } else {
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        };

        results.push(StateProofResult {
            action: payload.actions[idx].clone(),
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
    trie_id: &str,
    cur_roots: &mut HashMap<String, pathfinder_crypto::Felt>,
    original_roots: &mut HashMap<String, (pathfinder_crypto::Felt, TrieStorageIndex)>,
) -> Result<(), String> {
    if !state.tries.contains_key(trie_id) {
        let db_path = format!("/tmp/{}.db", trie_id);
        match StateServerTrie::new(&db_path) {
            Ok(new_trie) => {
                cur_roots.insert(trie_id.to_string(), new_trie.root_hash);
                original_roots.insert(trie_id.to_string(), (new_trie.root_hash, new_trie.root_idx));
                state.tries.insert(trie_id.to_string(), new_trie);
                Ok(())
            }
            Err(e) => Err(format!("Failed to create trie {}: {}", trie_id, e)),
        }
    } else {
        let trie = state.tries.get(trie_id).unwrap();
        cur_roots.insert(trie_id.to_string(), trie.root_hash);
        original_roots.insert(trie_id.to_string(), (trie.root_hash, trie.root_idx));
        Ok(())
    }
}

// Helper function to handle Read actions
fn handle_read_action(
    trie: &StateServerTrie,
    action: &dry_hint_processor::syscall_handler::injected_state::Action,
    trie_id: &str,
    cur_roots: &HashMap<String, pathfinder_crypto::Felt>,
) -> Result<StateProofWrapper, StatusCode> {
    let key_felt = match trie.string_to_felt(&action.key) {
        Ok(felt) => felt,
        Err(_) => return Err(StatusCode::BAD_REQUEST),
    };

    let conn = &trie
        .db_connection_manager
        .get_connection()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Get the current root hash for this trie
    let current_root = match cur_roots.get(trie_id) {
        Some(root) => *root,
        None => return Err(StatusCode::INTERNAL_SERVER_ERROR),
    };

    // Handle empty trie case
    if current_root == pathfinder_crypto::Felt::ZERO {
        return Ok(StateProofWrapper {
            trie_id: trie_id.to_string(),
            state_proof: StateProof::NonInclusion(vec![]),
            root_hash: pathfinder_crypto::Felt::ZERO,
            leaf: TrieLeaf {
                key: key_felt,
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
    let leaf = match db.get_leaf(key_felt) {
        Ok(leaf) => leaf,
        Err(_) => return Err(StatusCode::INTERNAL_SERVER_ERROR),
    };

    match Trie::get_leaf_proof(&db, current_root, leaf) {
        Ok(trie_proof) => {
            let key_exists = db
                .get_leaf(key_felt)
                .map(|stored_value| stored_value.data.value != pathfinder_crypto::Felt::ZERO)
                .unwrap_or(false);

            let proof_nodes: Vec<TrieNodeSerde> = trie_proof.into_iter().map(|(node, _)| node.into()).collect();

            if key_exists {
                Ok(StateProofWrapper {
                    trie_id: trie_id.to_string(),
                    state_proof: StateProof::Inclusion(proof_nodes),
                    root_hash: current_root,
                    leaf,
                    post_proof_root_hash: None,
                    post_proof_leaf: None,
                })
            } else {
                Ok(StateProofWrapper {
                    trie_id: trie_id.to_string(),
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
    cur_roots: &HashMap<String, pathfinder_crypto::Felt>,
    trie_id: &str,
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
    action: &dry_hint_processor::syscall_handler::injected_state::Action,
    trie_id: &str,
    cur_roots: &mut HashMap<String, pathfinder_crypto::Felt>,
) -> Result<StateProofWrapper, StatusCode> {
    let (key_felt, value_felt) = match (
        trie.string_to_felt(&action.key),
        trie.string_to_felt(action.value.as_ref().unwrap_or(&String::new())),
    ) {
        (Ok(k), Ok(v)) => (k, v),
        _ => return Err(StatusCode::BAD_REQUEST),
    };

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
    let pre_proof_leaf = storage.get_leaf(key_felt).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let pre_proof = generate_local_leaf_proof(&storage, cur_roots, trie_id, pre_proof_leaf)?;
    let pre_proof_root_hash = *cur_roots.get(trie_id).unwrap();

    let leaf = TrieLeaf::new(key_felt, value_felt);
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
            cur_roots.insert(trie_id.to_string(), new_root);

            // Generate post-proof
            let post_proof = generate_local_leaf_proof(&storage, cur_roots, trie_id, leaf)?;

            // Don't allow empty proofs for both pre and post unless it's a first write to empty trie
            if pre_proof.is_empty() && post_proof.is_empty() && trie.root_hash != pathfinder_crypto::Felt::ZERO {
                return Err(StatusCode::INTERNAL_SERVER_ERROR);
            }

            Ok(StateProofWrapper {
                trie_id: trie_id.to_string(),
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
    info!("  POST /get-state-proofs - Generate structured StateProof objects for actions (read=inclusion, write=update)");
    info!("  GET /get-key/{{trie_id}}?key=<key> - Get value of a key");
    info!("  GET /get-root-hash/{{trie_id}} - Get root hash of a trie");

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

    // Convert key/value decimal or hex string -> Felt
    fn str_to_felt(s: &str) -> pathfinder_crypto::Felt {
        if s.starts_with("0x") || s.starts_with("0X") {
            pathfinder_crypto::Felt::from_hex_str(s).unwrap()
        } else {
            let num = s.parse::<u128>().unwrap();
            let num_bytes = num.to_be_bytes();
            let mut full = [0u8; 32];
            full[16..].copy_from_slice(&num_bytes); // place in lower 16 bytes
            pathfinder_crypto::Felt::from_be_bytes(full).unwrap()
        }
    }

    fn build_request_new_trie(trie_id: &str) -> Request<Body> {
        Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap()
    }

    fn build_request_insert_initial_data(trie_id: &str, keys: &[&str], values: &[&str]) -> Request<Body> {
        Request::builder()
            .method("POST")
            .uri("/insert-initial-data")
            .header("content-type", "application/json")
            .body(Body::from(format!(
                r#"{{"trie_id": "{}", "keys": {:?}, "values": {:?}}}"#,
                trie_id, keys, values
            )))
            .unwrap()
    }

    #[tokio::test]
    async fn test_new_trie_with_id() {
        let app = create_router();
        let trie_id = format!("test-new-trie-{}", uuid::Uuid::new_v4());

        let response = app.oneshot(build_request_new_trie(&trie_id)).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();

        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: serde_json::Value = serde_json::from_str(&response_text).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert!(!response_body["root_hash"].is_null());
        assert!(response_body["root_hash"].is_string());
    }

    #[tokio::test]
    async fn test_get_state_proofs_read_only() {
        use tower::{util::ServiceExt, Service};

        let mut app = create_router();

        let trie_id = format!("test_get_state_proofs_read_only_{}", uuid::Uuid::new_v4());
        let response = app.clone().oneshot(build_request_new_trie(&trie_id)).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let keys = vec!["120368059344249".to_string(), "42".to_string(), "100000000000000".to_string()];
        let values = vec!["555".to_string(), "777".to_string(), "999".to_string()];

        let response = app
            .clone()
            .oneshot(build_request_insert_initial_data(
                &trie_id,
                &keys.iter().map(|k| k.as_str()).collect::<Vec<&str>>(),
                &values.iter().map(|v| v.as_str()).collect::<Vec<&str>>(),
            ))
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let combined_actions = vec![
            // Read existing keys
            format!("{};0;120368059344249", trie_id),
            format!("{};0;42", trie_id),
            format!("{};0;100000000000000", trie_id),
            // Read non-existing key
            format!("{};0;999999999999999", trie_id),
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
            let key = match i {
                0 => str_to_felt("120368059344249"),
                1 => str_to_felt("42"),
                2 => str_to_felt("100000000000000"),
                3 => str_to_felt("999999999999999"), // Non-existing
                _ => panic!("Unexpected proof index"),
            };
            let value = match i {
                0 => str_to_felt("555"),
                1 => str_to_felt("777"),
                2 => str_to_felt("999"),
                3 => str_to_felt("0"), // Non-existing
                _ => panic!("Unexpected proof index"),
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

    fn build_request_get_key(trie_id: &str, key: &str) -> Request<Body> {
        Request::builder()
            .method("GET")
            .uri(format!("/get-key/{}?key={}", trie_id, key))
            .body(Body::from(""))
            .unwrap()
    }

    #[tokio::test]
    async fn test_get_state_proofs_read_write() {
        use tower::{util::ServiceExt, Service};

        let mut app = create_router();

        let trie_id = format!("test_get_state_proofs_read_write{}", uuid::Uuid::new_v4());

        let combined_actions = vec![
            // Write existing keys
            format!("{};1;120368059344249;555", trie_id),
            format!("{};1;42;777", trie_id),
            format!("{};1;100000000000000;999", trie_id),
            // Read existing keys
            format!("{};0;120368059344249", trie_id),
            format!("{};0;42", trie_id),
            format!("{};0;100000000000000", trie_id),
            // Read non-existing key
            format!("{};0;999999999999999", trie_id),
            // Overwrite 42 key
            format!("{};1;42;1000", trie_id),
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
            let key = match i {
                0 => str_to_felt("120368059344249"),
                1 => str_to_felt("42"),
                2 => str_to_felt("100000000000000"),
                3 => str_to_felt("120368059344249"),
                4 => str_to_felt("42"),
                5 => str_to_felt("100000000000000"),
                6 => str_to_felt("999999999999999"), // Non-existing
                7 => str_to_felt("42"),
                _ => panic!("Unexpected proof index"),
            };
            let value = match i {
                0 => str_to_felt("555"),
                1 => str_to_felt("777"),
                2 => str_to_felt("999"),
                3 => str_to_felt("555"),
                4 => str_to_felt("777"),
                5 => str_to_felt("999"),
                6 => str_to_felt("0"), // Non-existing
                7 => str_to_felt("1000"),
                _ => panic!("Unexpected proof index"),
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
            for key in ["120368059344249", "42", "100000000000000"] {
                let response = app
                    .clone()
                    .oneshot(build_request_get_key(&trie_id, &key.to_string()))
                    .await
                    .unwrap();
                assert_eq!(response.status(), StatusCode::NOT_FOUND);
            }
        }
    }

    #[tokio::test]
    async fn test_get_state_proofs_from_dry_run_output() {
        use tower::{util::ServiceExt, Service};

        let mut app = create_router();

        let trie_id = format!("test_get_state_proofs_read_write_with_data{}", uuid::Uuid::new_v4());

        let combined_actions = vec![
            format!("{};1;120368059344249;12345", trie_id),
            format!("{};0;120368059344249", trie_id),
            format!("{};0;120368059344249", trie_id),
            format!("{};0;121424621299065", trie_id),
            format!("{};1;120368059344249;54321", trie_id),
            format!("{};0;120368059344249", trie_id),
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
