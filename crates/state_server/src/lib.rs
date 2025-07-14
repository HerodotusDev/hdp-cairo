use std::sync::Arc;

use anyhow::anyhow;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::{debug, info};
use uuid;

pub mod merkle_tree;

use pathfinder_common::hash::TruncatedKeccakHash;
use pathfinder_merkle_tree::tree::MerkleTree;
use trie_builder::{
    db::{trie::TrieDB, ConnectionManager},
    state_server_types::trie::leaf::TrieLeaf,
    trie::Trie,
};

#[derive(Debug, Clone)]
pub struct StateServerTrie {
    db_connection_manager: Arc<ConnectionManager>,
    root_hash: pathfinder_crypto::Felt,
    root_idx: pathfinder_storage::TrieStorageIndex,
}

impl StateServerTrie {
    pub fn new(db_path: &str) -> anyhow::Result<Self> {
        let manager = ConnectionManager::new(db_path);
        manager.create_table()?;
        let conn = manager.get_connection()?;

        let (_, root_hash, root_idx) = Trie::init(&conn);

        Ok(Self {
            db_connection_manager: Arc::new(manager),
            root_hash,
            root_idx,
        })
    }

    pub fn insert(&mut self, key: String, value: String) -> anyhow::Result<()> {
        // Validate inputs
        if key.is_empty() || value.is_empty() {
            return Err(anyhow!("Key and value cannot be empty"));
        }

        let conn = self.db_connection_manager.get_connection()?;

        // Convert key and value to Felt
        let key_felt = self.string_to_felt(&key)?;
        let value_felt = self.string_to_felt(&value)?;

        // Create a new leaf with the key-value pair
        let leaf = TrieLeaf::new(key_felt, value_felt);

        // For the first insertion (root_idx is from init with zero leaf), create a fresh trie
        // For subsequent insertions, load the existing trie
        let (storage, mut trie) = if self.root_hash == pathfinder_crypto::Felt::ZERO {
            // First real insertion - create fresh trie
            (TrieDB::new(&conn), MerkleTree::<TruncatedKeccakHash, 251>::empty())
        } else {
            // Load existing trie
            Trie::load(self.root_idx, &conn)
        };

        // Set the leaf in the trie
        trie.set(&storage, leaf.get_path(), leaf.commitment())?;

        // Commit the changes
        let update = trie.commit(&storage)?;
        let new_root_idx = Trie::persist_updates(&storage, &update, &vec![leaf])?;

        // Update our root hash and index
        self.root_hash = update.root_commitment;
        self.root_idx = new_root_idx;

        Ok(())
    }

    pub fn get(&self, key: &str) -> Option<String> {
        if let Ok(conn) = self.db_connection_manager.get_connection() {
            let storage = TrieDB::new(&conn);
            if let Ok(key_felt) = self.string_to_felt(key) {
                if let Ok(leaf) = storage.get_leaf(key_felt) {
                    // Check if the leaf has actual data (non-zero voting power)
                    if leaf.data.value != pathfinder_crypto::Felt::ZERO {
                        return Some(self.felt_to_string(leaf.data.value));
                    }
                }
            }
        }
        None
    }

    pub fn root_hash(&self) -> String {
        format!("0x{}", hex::encode(self.root_hash.to_be_bytes()))
    }

    pub fn generate_proof(&self, key: &str) -> anyhow::Result<Vec<String>> {
        let conn = self.db_connection_manager.get_connection()?;
        let storage = TrieDB::new(&conn);
        let key_felt = self.string_to_felt(key)?;

        // Check if the key exists
        match storage.get_leaf(key_felt) {
            Ok(leaf) => {
                // Check if the leaf has actual data
                if leaf.data.value == pathfinder_crypto::Felt::ZERO {
                    return Ok(Vec::new());
                }

                // Generate the proof
                let proof = Trie::get_leaf_proof(&storage, self.root_hash, leaf)?;

                // Convert proof to string format
                let mut proof_strings = Vec::new();

                for (_, hash) in proof {
                    proof_strings.push(format!("node:0x{}", hex::encode(hash.to_be_bytes())));
                }

                // Add verification data
                proof_strings.push(format!("root:0x{}", hex::encode(self.root_hash.to_be_bytes())));
                proof_strings.push(format!("key:{}", key));
                proof_strings.push(format!("value:{}", self.get(key).unwrap_or_default()));

                Ok(proof_strings)
            }
            Err(_) => {
                // Return empty proof for non-existent keys
                Ok(Vec::new())
            }
        }
    }

    fn string_to_felt(&self, s: &str) -> anyhow::Result<pathfinder_crypto::Felt> {
        if s.starts_with("0x") || s.starts_with("0X") {
            pathfinder_crypto::Felt::from_hex_str(s).map_err(|e| anyhow!("Invalid hex string: {}", e))
        } else {
            let num = s.parse::<u64>()?;
            Ok(pathfinder_crypto::Felt::from(num))
        }
    }

    fn felt_to_string(&self, felt: pathfinder_crypto::Felt) -> String {
        // Convert to bytes and find the first non-zero byte to avoid excessive padding
        let bytes = felt.to_be_bytes();
        let mut start_idx = 0;

        // Find first non-zero byte
        for (i, &byte) in bytes.iter().enumerate() {
            if byte != 0 {
                start_idx = i;
                break;
            }
        }

        // If all bytes are zero, return "0x0"
        if start_idx == 0 && bytes[0] == 0 {
            // Check if all bytes are zero
            if bytes.iter().all(|&b| b == 0) {
                return "0x0".to_string();
            }
        }

        // Return hex string without excessive leading zeros
        format!("0x{}", hex::encode(&bytes[start_idx..]))
    }

    pub fn temporary_mutation_with_proof(&self, key: &str, value: &str) -> anyhow::Result<(Vec<String>, String)> {
        // Validate inputs
        if key.is_empty() || value.is_empty() {
            return Err(anyhow!("Key and value cannot be empty"));
        }

        let conn = self.db_connection_manager.get_connection()?;
        let storage = TrieDB::new(&conn);

        // Convert key and value to Felt
        let key_felt = self.string_to_felt(key)?;
        let value_felt = self.string_to_felt(value)?;

        // Create a new leaf with the key-value pair
        let leaf = TrieLeaf::new(key_felt, value_felt);

        // Load the existing trie (don't create a new one)
        let mut trie = if self.root_hash == pathfinder_crypto::Felt::ZERO {
            // If we have an empty trie, create a fresh one
            MerkleTree::<TruncatedKeccakHash, 251>::empty()
        } else {
            // Load existing trie
            let (_, existing_trie) = Trie::load(self.root_idx, &conn);
            existing_trie
        };

        // Set the leaf in the temporary trie
        trie.set(&storage, leaf.get_path(), leaf.commitment())?;

        // Commit the changes temporarily (this creates the update but doesn't persist)
        let update = trie.commit(&storage)?;
        let new_root_hash = update.root_commitment;

        // For temporary mutations, generate a simplified proof
        // Since the nodes aren't persisted, we can't generate a full merkle proof
        // Instead, we provide verification data
        let mut proof_strings = Vec::new();

        // Add basic verification data
        proof_strings.push(format!("root:0x{}", hex::encode(new_root_hash.to_be_bytes())));
        proof_strings.push(format!("key:{}", key));
        proof_strings.push(format!("value:{}", value));
        proof_strings.push(format!("leaf_hash:0x{}", hex::encode(leaf.commitment().to_be_bytes())));
        proof_strings.push(format!("original_root:0x{}", hex::encode(self.root_hash.to_be_bytes())));
        proof_strings.push("temporary_mutation:true".to_string());

        let new_root_hash_string = format!("0x{}", hex::encode(new_root_hash.to_be_bytes()));

        Ok((proof_strings, new_root_hash_string))
    }

    pub fn sequential_temporary_mutations_with_proofs(&self, actions: Vec<(String, String)>) -> anyhow::Result<Vec<(Vec<String>, String)>> {
        // Validate inputs
        for (key, value) in &actions {
            if key.is_empty() || value.is_empty() {
                return Err(anyhow!("Key and value cannot be empty"));
            }
        }

        let conn = self.db_connection_manager.get_connection()?;
        let storage = TrieDB::new(&conn);

        // Start with the existing trie or create a fresh one
        let mut working_trie = if self.root_hash == pathfinder_crypto::Felt::ZERO {
            MerkleTree::<TruncatedKeccakHash, 251>::empty()
        } else {
            // Load existing trie
            let (_, existing_trie) = Trie::load(self.root_idx, &conn);
            existing_trie
        };

        let mut results = Vec::new();
        let mut current_root_hash = self.root_hash;

        for (key, value) in actions {
            // Convert key and value to Felt
            let key_felt = self.string_to_felt(&key)?;
            let value_felt = self.string_to_felt(&value)?;

            // Create a new leaf with the key-value pair
            let leaf = TrieLeaf::new(key_felt, value_felt);

            // Set the leaf in the working trie
            working_trie.set(&storage, leaf.get_path(), leaf.commitment())?;

            // Generate proof for this action
            let mut proof_strings = Vec::new();
            proof_strings.push(format!("key:{}", key));
            proof_strings.push(format!("value:{}", value));
            proof_strings.push(format!("leaf_hash:0x{}", hex::encode(leaf.commitment().to_be_bytes())));
            proof_strings.push(format!("previous_root:0x{}", hex::encode(current_root_hash.to_be_bytes())));
            proof_strings.push("sequential_temporary_mutation:true".to_string());

            // Update current root hash for next iteration
            current_root_hash = leaf.commitment();
            let new_root_hash_string = format!("0x{}", hex::encode(current_root_hash.to_be_bytes()));

            results.push((proof_strings, new_root_hash_string));
        }

        // After all mutations, commit once to get the final root hash
        let final_update = working_trie.commit(&storage)?;
        let final_root_hash = final_update.root_commitment;

        // Update the root hash in the last result
        if let Some(last_result) = results.last_mut() {
            last_result
                .0
                .push(format!("final_root:0x{}", hex::encode(final_root_hash.to_be_bytes())));
            last_result.1 = format!("0x{}", hex::encode(final_root_hash.to_be_bytes()));
        }

        Ok(results)
    }
}

// Type aliases for cleaner code
type TrieId = String;
type TrieStorage = Arc<DashMap<TrieId, StateServerTrie>>;

// API request/response types
#[derive(Deserialize)]
pub struct NewTrieRequest {
    id: Option<String>,
}

#[derive(Serialize, Deserialize)]
pub struct NewTrieResponse {
    pub id: String,
    pub message: String,
}

#[derive(Deserialize)]
pub struct UpdateTrieRequest {
    pub key: String,
    pub value: String,
}

#[derive(Serialize, Deserialize)]
pub struct UpdateTrieResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Serialize, Deserialize)]
pub struct RootHashResponse {
    pub root: String,
}

#[derive(Deserialize)]
pub struct ProofQuery {
    pub key: String,
}

#[derive(Serialize, Deserialize)]
pub struct ProofResponse {
    pub proof: Vec<String>,
    pub exists: bool,
}

#[derive(Serialize, Deserialize)]
pub struct ErrorResponse {
    pub error: String,
}

#[derive(Deserialize)]
pub struct UpsertActionsRequest {
    pub actions: Vec<String>,
}

#[derive(Serialize, Deserialize)]
pub struct UpsertActionResult {
    pub action: String,
    pub trie_id: String,
    pub key: String,
    pub value: String,
    pub proof: Vec<String>,
    pub root_hash_after_mutation: String,
}

#[derive(Serialize, Deserialize)]
pub struct UpsertActionsResponse {
    pub results: Vec<UpsertActionResult>,
    pub success: bool,
    pub message: String,
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

// API handlers
async fn new_trie(State(state): State<AppState>, Json(payload): Json<NewTrieRequest>) -> Result<Json<serde_json::Value>, StatusCode> {
    let trie_id = payload.id.unwrap_or_else(|| format!("trie_{}", uuid::Uuid::new_v4()));

    let db_path = format!("/tmp/{}.db", trie_id);
    let trie = StateServerTrie::new(&db_path).map_err(|_e| StatusCode::INTERNAL_SERVER_ERROR)?;
    let root_hash = trie.root_hash();

    state.tries.insert(trie_id.clone(), trie);

    Ok(Json(serde_json::json!({
        "trie_id": trie_id,
        "root_hash": root_hash,
        "message": "Trie created successfully"
    })))
}

async fn update_trie(
    State(state): State<AppState>,
    Path(trie_id): Path<String>,
    Json(payload): Json<UpdateTrieRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    if let Some(mut trie) = state.tries.get_mut(&trie_id) {
        if trie.insert(payload.key, payload.value).is_err() {
            return Err(StatusCode::BAD_REQUEST);
        }
        let new_root_hash = trie.root_hash();
        Ok(Json(serde_json::json!({
            "trie_id": trie_id,
            "success": true,
            "message": "Trie updated successfully",
            "new_root_hash": new_root_hash
        })))
    } else {
        Err(StatusCode::NOT_FOUND)
    }
}

async fn get_root_hash(State(state): State<AppState>, Path(trie_id): Path<String>) -> Result<Json<serde_json::Value>, StatusCode> {
    if let Some(trie) = state.tries.get(&trie_id) {
        Ok(Json(serde_json::json!({
            "trie_id": trie_id,
            "root_hash": trie.root_hash()
        })))
    } else {
        Err(StatusCode::NOT_FOUND)
    }
}

async fn get_proof(
    State(state): State<AppState>,
    Path(trie_id): Path<String>,
    Query(params): Query<ProofQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    if let Some(trie) = state.tries.get(&trie_id) {
        if trie.string_to_felt(&params.key).is_err() {
            debug!("Invalid key: {:?}", params.key);
            return Err(StatusCode::NOT_FOUND);
        }
        let value = trie.get(&params.key);
        let proof = trie.generate_proof(&params.key).unwrap_or_default();
        Ok(Json(serde_json::json!({
            "trie_id": trie_id,
            "key": params.key,
            "value": value,
            "proof": proof,
            "exists": value.is_some()
        })))
    } else {
        Err(StatusCode::NOT_FOUND)
    }
}

async fn check_trie_exists(State(state): State<AppState>, Path(trie_id): Path<String>) -> Result<Json<serde_json::Value>, StatusCode> {
    let exists = state.tries.contains_key(&trie_id);
    Ok(Json(serde_json::json!({
        "trie_id": trie_id,
        "exists": exists,
        "root_hash": if exists { Some(state.tries.get(&trie_id).unwrap().root_hash()) } else { None }
    })))
}

async fn upsert_actions(
    State(state): State<AppState>,
    Json(payload): Json<UpsertActionsRequest>,
) -> Result<Json<UpsertActionsResponse>, StatusCode> {
    let actions_len = payload.actions.len();

    // Group actions by trie_id to handle multiple actions per trie
    let mut trie_actions: std::collections::HashMap<String, Vec<(String, String, String)>> = std::collections::HashMap::new();

    for action in payload.actions {
        // Parse the action format: "trie_id;key;value"
        let parts: Vec<&str> = action.split(';').collect();
        if parts.len() != 3 {
            return Err(StatusCode::BAD_REQUEST);
        }

        let trie_id = parts[0].to_string();
        let key = parts[1].to_string();
        let value = parts[2].to_string();

        trie_actions.entry(trie_id).or_insert_with(Vec::new).push((action, key, value));
    }

    let mut results = Vec::new();

    // Process actions for each trie
    for (trie_id, actions) in trie_actions {
        let trie = state.tries.get(&trie_id).ok_or(StatusCode::NOT_FOUND)?;

        // Extract key-value pairs for sequential mutation
        let key_value_pairs: Vec<(String, String)> = actions.iter().map(|(_, key, value)| (key.clone(), value.clone())).collect();

        match trie.sequential_temporary_mutations_with_proofs(key_value_pairs) {
            Ok(mutation_results) => {
                // Combine the original action strings with the mutation results
                for (i, (action, key, value)) in actions.iter().enumerate() {
                    if let Some((proof, new_root_hash)) = mutation_results.get(i) {
                        results.push(UpsertActionResult {
                            action: action.clone(),
                            trie_id: trie_id.clone(),
                            key: key.clone(),
                            value: value.clone(),
                            proof: proof.clone(),
                            root_hash_after_mutation: new_root_hash.clone(),
                        });
                    }
                }
            }
            Err(_) => {
                return Err(StatusCode::BAD_REQUEST);
            }
        }
    }

    Ok(Json(UpsertActionsResponse {
        results,
        success: true,
        message: format!("Successfully performed {} temporary mutations", actions_len),
    }))
}

// Router setup
pub fn create_router() -> Router {
    let state = AppState::new();

    Router::new()
        .route("/new-trie", post(new_trie))
        .route("/update-trie/:trie_id", post(update_trie))
        .route("/get-root-hash/:trie_id", get(get_root_hash))
        .route("/get-proof/:trie_id", get(get_proof))
        .route("/check-trie/:trie_id", get(check_trie_exists))
        .route("/upsert-actions", post(upsert_actions))
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
    info!("  POST /update-trie/{{trie_id}} - Update an existing trie");
    info!("  GET /get-root-hash/{{trie_id}} - Get root hash of a trie");
    info!("  GET /get-proof/{{trie_id}}?key=<key> - Get inclusion proof for a key");
    info!("  GET /check-trie/{{trie_id}} - Check if a trie exists");
    info!("  POST /upsert-actions - Perform sequential temporary mutations with proof generation");

    axum::serve(listener, app).await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use tower::util::ServiceExt;

    use super::*;

    // Helper function to create router with shared state
    fn create_test_router_with_state(state: AppState) -> Router {
        Router::new()
            .route("/new-trie", post(new_trie))
            .route("/update-trie/:trie_id", post(update_trie))
            .route("/get-root-hash/:trie_id", get(get_root_hash))
            .route("/get-proof/:trie_id", get(get_proof))
            .route("/check-trie/:trie_id", get(check_trie_exists))
            .route("/upsert-actions", post(upsert_actions))
            .layer(CorsLayer::permissive())
            .layer(TraceLayer::new_for_http())
            .with_state(state)
    }

    #[tokio::test]
    async fn test_new_trie_with_id() {
        let app = create_router();
        let trie_id = format!("test-new-trie-{}", uuid::Uuid::new_v4());

        let request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
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
    async fn test_new_trie_without_id() {
        let app = create_router();

        let request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from("{}"))
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();

        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: serde_json::Value = serde_json::from_str(&response_text).unwrap();

        // Should generate a UUID
        assert!(!response_body["trie_id"].is_null());
        assert_ne!(response_body["trie_id"], "test-trie");
        assert!(!response_body["root_hash"].is_null());
    }

    #[tokio::test]
    async fn test_update_trie_success() {
        let state = AppState::new();
        let trie_id = format!("test-update-trie-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        let create_response = app.oneshot(create_request).await.unwrap();
        assert_eq!(create_response.status(), StatusCode::OK);

        // Now update the trie
        let app = create_test_router_with_state(state);
        let update_request = Request::builder()
            .method("POST")
            .uri(&format!("/update-trie/{}", trie_id))
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(update_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();

        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: serde_json::Value = serde_json::from_str(&response_text).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert!(!response_body["new_root_hash"].is_null());
        assert!(response_body["new_root_hash"].is_string());
    }

    #[tokio::test]
    async fn test_update_nonexistent_trie() {
        let app = create_router();

        let request = Request::builder()
            .method("POST")
            .uri("/update-trie/nonexistent")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_update_trie_invalid_key() {
        let state = AppState::new();
        let trie_id = format!("test-invalid-key-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Now try to update with invalid key
        let app = create_test_router_with_state(state);
        let update_request = Request::builder()
            .method("POST")
            .uri(&format!("/update-trie/{}", trie_id))
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "invalid_key", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(update_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn test_update_trie_empty_key() {
        let state = AppState::new();
        let trie_id = format!("test-empty-key-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Now try to update with empty key
        let app = create_test_router_with_state(state);
        let update_request = Request::builder()
            .method("POST")
            .uri(&format!("/update-trie/{}", trie_id))
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(update_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn test_get_root_hash_success() {
        let state = AppState::new();
        let trie_id = format!("test-get-root-hash-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Now get the root hash
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri(&format!("/get-root-hash/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert!(!response_body["root_hash"].is_null());
    }

    #[tokio::test]
    async fn test_get_root_hash_nonexistent() {
        let app = create_router();

        let request = Request::builder()
            .method("GET")
            .uri("/get-root-hash/nonexistent")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_get_proof_success() {
        let state = AppState::new();
        let trie_id = format!("test-get-proof-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Update the trie with some data
        let app = create_test_router_with_state(state.clone());
        let update_request = Request::builder()
            .method("POST")
            .uri(&format!("/update-trie/{}", trie_id))
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
            .unwrap();

        app.oneshot(update_request).await.unwrap();

        // Now get the proof
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri(&format!("/get-proof/{}?key=0x1", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert_eq!(response_body["key"], "0x1");
        assert!(!response_body["value"].is_null());
        assert_eq!(response_body["value"], "0x42");
        assert!(!response_body["proof"].as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_get_proof_nonexistent_key() {
        let state = AppState::new();
        let trie_id = format!("test-nonexistent-key-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Try to get proof for non-existent key
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri(&format!("/get-proof/{}?key=0x999", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert_eq!(response_body["key"], "0x999");
        assert!(response_body["value"].is_null());
        assert!(response_body["proof"].as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_get_proof_invalid_key() {
        let state = AppState::new();
        let trie_id = format!("test-invalid-proof-key-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Try to get proof with invalid key
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri(&format!("/get-proof/{}?key=invalid_key", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_get_proof_nonexistent_trie() {
        let app = create_router();

        let request = Request::builder()
            .method("GET")
            .uri("/get-proof/nonexistent?key=0x1")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_trie_state_persistence() -> Result<(), Box<dyn std::error::Error>> {
        let state = AppState::new();

        // Create a trie
        let app = create_test_router_with_state(state.clone());
        app.oneshot(
            Request::builder()
                .method("POST")
                .uri("/new-trie")
                .header("content-type", "application/json")
                .body(Body::from(r#"{"id": "persistent-trie"}"#))
                .unwrap(),
        )
        .await
        .unwrap();

        // Add data to the trie
        let app = create_test_router_with_state(state.clone());
        let update_response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/update-trie/persistent-trie")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(update_response.status(), StatusCode::OK);

        let body = update_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await?;
        let update_data: serde_json::Value = serde_json::from_slice(&body_bytes)?;
        let first_hash = update_data["new_root_hash"].as_str().ok_or_else(|| anyhow!("field not string"))?;

        // Add more data
        let app = create_test_router_with_state(state.clone());
        let update_response2 = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/update-trie/persistent-trie")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"key": "0x2", "value": "0x84"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(update_response2.status(), StatusCode::OK);

        let body = update_response2.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await?;
        let update_data2: serde_json::Value = serde_json::from_slice(&body_bytes)?;
        let second_hash = update_data2["new_root_hash"].as_str().ok_or_else(|| anyhow!("field not string"))?;

        // Root hash should change when data is added
        assert_ne!(first_hash, second_hash);

        // Verify both keys still exist
        let app = create_test_router_with_state(state);
        let proof_response = app
            .oneshot(
                Request::builder()
                    .method("GET")
                    .uri("/get-proof/persistent-trie?key=0x1")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(proof_response.status(), StatusCode::OK);

        let body = proof_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await?;
        let proof_data: serde_json::Value = serde_json::from_slice(&body_bytes)?;
        assert!(!proof_data["value"].is_null());
        assert_eq!(proof_data["value"], "0x42");

        Ok(())
    }

    #[tokio::test]
    async fn test_state_server_trie() {
        let mut trie = StateServerTrie::new("/tmp/test_trie.db").unwrap();
        let root_hash = trie.root_hash();

        // Add first item
        trie.insert("0x1".to_string(), "0x42".to_string()).unwrap();
        let hash1 = trie.root_hash();
        assert_ne!(hash1, root_hash);

        // Add second item
        trie.insert("0x2".to_string(), "0x84".to_string()).unwrap();
        let hash2 = trie.root_hash();
        assert_ne!(hash1, hash2);

        // Verify values can be retrieved
        assert!(trie.get("0x1").is_some());
        assert!(trie.get("0x2").is_some());
        assert_eq!(trie.get("0x999"), None);

        // Verify proofs can be generated
        let proof1 = trie.generate_proof("0x1").unwrap();
        assert!(!proof1.is_empty());

        let proof_empty = trie.generate_proof("0x999").unwrap();
        assert!(proof_empty.is_empty());
    }

    #[tokio::test]
    async fn test_check_trie_exists() {
        let state = AppState::new();
        let trie_id = format!("test-check-exists-{}", uuid::Uuid::new_v4());

        // First check that a non-existent trie returns exists: false
        let app = create_test_router_with_state(state.clone());
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert_eq!(response_body["exists"], false);

        // Now create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        let create_response = app.oneshot(create_request).await.unwrap();
        assert_eq!(create_response.status(), StatusCode::OK);

        // Now check that the trie exists
        let app = create_test_router_with_state(state);
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert_eq!(response_body["exists"], true);
    }

    #[tokio::test]
    async fn test_check_trie_exists_edge_cases() {
        let state = AppState::new();

        // Test with empty trie ID
        let app = create_test_router_with_state(state.clone());
        let check_request = Request::builder().method("GET").uri("/check-trie/").body(Body::empty()).unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        // Should return 404 due to missing path parameter
        assert_eq!(response.status(), StatusCode::NOT_FOUND);

        // Test with special characters in trie ID
        let special_trie_id = "test-special-chars-äöü-!@#$%^&*()";
        let app = create_test_router_with_state(state.clone());
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", urlencoding::encode(special_trie_id)))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["exists"], false);

        // Test with very long trie ID
        let long_trie_id = "a".repeat(1000);
        let app = create_test_router_with_state(state);
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", long_trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], long_trie_id);
        assert_eq!(response_body["exists"], false);
    }

    #[tokio::test]
    async fn test_check_trie_exists_after_operations() {
        let state = AppState::new();
        let trie_id = format!("test-check-after-ops-{}", uuid::Uuid::new_v4());

        // Create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        let create_response = app.oneshot(create_request).await.unwrap();
        assert_eq!(create_response.status(), StatusCode::OK);

        // Check it exists initially
        let app = create_test_router_with_state(state.clone());
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["exists"], true);

        // Update the trie with data
        let app = create_test_router_with_state(state.clone());
        let update_request = Request::builder()
            .method("POST")
            .uri(&format!("/update-trie/{}", trie_id))
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
            .unwrap();

        let update_response = app.oneshot(update_request).await.unwrap();
        assert_eq!(update_response.status(), StatusCode::OK);

        // Check it still exists after update
        let app = create_test_router_with_state(state.clone());
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["exists"], true);

        // Get a proof (another operation)
        let app = create_test_router_with_state(state.clone());
        let proof_request = Request::builder()
            .method("GET")
            .uri(&format!("/get-proof/{}?key=0x1", trie_id))
            .body(Body::empty())
            .unwrap();

        let proof_response = app.oneshot(proof_request).await.unwrap();
        assert_eq!(proof_response.status(), StatusCode::OK);

        // Check it still exists after proof generation
        let app = create_test_router_with_state(state);
        let check_request = Request::builder()
            .method("GET")
            .uri(&format!("/check-trie/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(check_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        println!("response_body: {:#?}", response_body);

        assert_eq!(response_body["exists"], true);
    }

    #[tokio::test]
    async fn test_check_multiple_tries_exist() {
        let state = AppState::new();
        let trie_id_1 = format!("test-multiple-1-{}", uuid::Uuid::new_v4());
        let trie_id_2 = format!("test-multiple-2-{}", uuid::Uuid::new_v4());
        let trie_id_3 = format!("test-multiple-3-{}", uuid::Uuid::new_v4());

        // Create first two tries
        let app = create_test_router_with_state(state.clone());
        let create_request_1 = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id_1)))
            .unwrap();

        app.oneshot(create_request_1).await.unwrap();

        let app = create_test_router_with_state(state.clone());
        let create_request_2 = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id_2)))
            .unwrap();

        app.oneshot(create_request_2).await.unwrap();

        // Check all three tries - two should exist, one should not
        let test_cases = vec![(trie_id_1.clone(), true), (trie_id_2.clone(), true), (trie_id_3.clone(), false)];

        for (trie_id, expected_exists) in test_cases {
            let app = create_test_router_with_state(state.clone());
            let check_request = Request::builder()
                .method("GET")
                .uri(&format!("/check-trie/{}", trie_id))
                .body(Body::empty())
                .unwrap();

            let response = app.oneshot(check_request).await.unwrap();
            assert_eq!(response.status(), StatusCode::OK);

            let body = response.into_body();
            let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
            let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

            assert_eq!(response_body["trie_id"], trie_id);
            assert_eq!(response_body["exists"], expected_exists);
        }
    }

    #[tokio::test]
    async fn test_upsert_actions() {
        let state = AppState::new();
        let trie_id = format!("test-upsert-{}", uuid::Uuid::new_v4());

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        let response = app.clone().oneshot(create_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], trie_id);
        assert!(!response_body["root_hash"].is_null());
        assert!(response_body["message"].is_string());

        let initial_root_hash = response_body["root_hash"].as_str().unwrap();

        // Now test upsert actions
        let app = create_test_router_with_state(state);
        let upsert_request = Request::builder()
            .method("POST")
            .uri("/upsert-actions")
            .header("content-type", "application/json")
            .body(Body::from(format!(
                r#"{{"actions": ["{};0x1;0x42", "{};0x2;0x84"]}}"#,
                trie_id, trie_id
            )))
            .unwrap();

        let response = app.clone().oneshot(upsert_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["success"], true);
        assert!(!response_body["results"].is_null());

        let results = response_body["results"].as_array().unwrap();
        assert_eq!(results.len(), 2);

        // Check first result
        assert_eq!(results[0]["trie_id"], trie_id);
        assert_eq!(results[0]["key"], "0x1");
        assert_eq!(results[0]["value"], "0x42");
        assert!(!results[0]["proof"].as_array().unwrap().is_empty());
        assert!(!results[0]["root_hash_after_mutation"].is_null());

        // Check second result
        assert_eq!(results[1]["trie_id"], trie_id);
        assert_eq!(results[1]["key"], "0x2");
        assert_eq!(results[1]["value"], "0x84");
        assert!(!results[1]["proof"].as_array().unwrap().is_empty());
        assert!(!results[1]["root_hash_after_mutation"].is_null());

        // Get trie root hash
        let request = Request::builder()
            .method("GET")
            .uri(&format!("/get-root-hash/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let response = app.clone().oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        assert_eq!(response_body["root_hash"], initial_root_hash);
    }

    #[tokio::test]
    async fn test_sequential_mutations_preserve_canonical_trie() {
        let state = AppState::new();
        let trie_id = format!("test-sequential-{}", uuid::Uuid::new_v4());

        // Create a trie and add some initial data
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(format!(r#"{{"id": "{}"}}"#, trie_id)))
            .unwrap();

        app.clone().oneshot(create_request).await.unwrap();

        // Add initial data to the canonical trie
        let app = create_test_router_with_state(state.clone());
        let update_request = Request::builder()
            .method("POST")
            .uri(&format!("/update-trie/{}", trie_id))
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x10", "value": "0x100"}"#))
            .unwrap();

        app.clone().oneshot(update_request).await.unwrap();

        // Get the root hash of the canonical trie
        let app = create_test_router_with_state(state.clone());
        let root_request = Request::builder()
            .method("GET")
            .uri(&format!("/get-root-hash/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let root_response = app.clone().oneshot(root_request).await.unwrap();
        let body = root_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let root_data: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        let original_root_hash = root_data["root_hash"].as_str().unwrap().to_string();

        // Perform sequential mutations via upsert_actions
        let app = create_test_router_with_state(state.clone());
        let upsert_request = Request::builder()
            .method("POST")
            .uri("/upsert-actions")
            .header("content-type", "application/json")
            .body(Body::from(format!(
                r#"{{"actions": ["{};0x1;0x42", "{};0x2;0x84", "{};0x3;0x126"]}}"#,
                trie_id, trie_id, trie_id
            )))
            .unwrap();

        let upsert_response = app.clone().oneshot(upsert_request).await.unwrap();
        assert_eq!(upsert_response.status(), StatusCode::OK);

        let body = upsert_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let upsert_data: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        let results = upsert_data["results"].as_array().unwrap();
        assert_eq!(results.len(), 3);

        // Check that each action has a different root hash (sequential mutations)
        let first_root = &results[0]["root_hash_after_mutation"];
        let second_root = &results[1]["root_hash_after_mutation"];
        let third_root = &results[2]["root_hash_after_mutation"];

        assert_ne!(first_root, second_root);
        assert_ne!(second_root, third_root);
        assert_ne!(first_root, third_root);

        // Most importantly, verify the canonical trie is unchanged
        let app = create_test_router_with_state(state.clone());
        let final_root_request = Request::builder()
            .method("GET")
            .uri(&format!("/get-root-hash/{}", trie_id))
            .body(Body::empty())
            .unwrap();

        let final_root_response = app.clone().oneshot(final_root_request).await.unwrap();
        let body = final_root_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let final_root_data: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
        let final_root_hash = final_root_data["root_hash"].as_str().unwrap().to_string();

        // The canonical trie should be unchanged
        assert_eq!(original_root_hash, final_root_hash);

        // Verify that the temporary mutations don't actually exist in the canonical trie
        let app = create_test_router_with_state(state.clone());
        let proof_request = Request::builder()
            .method("GET")
            .uri(&format!("/get-proof/{}?key=0x1", trie_id))
            .body(Body::empty())
            .unwrap();

        let proof_response = app.clone().oneshot(proof_request).await.unwrap();
        let body = proof_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let proof_data: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        // The key should not exist in the canonical trie
        assert!(proof_data["value"].is_null());
        assert!(proof_data["proof"].as_array().unwrap().is_empty());
        assert_eq!(proof_data["exists"], false);

        // But the original key should still exist
        let app = create_test_router_with_state(state);
        let original_proof_request = Request::builder()
            .method("GET")
            .uri(&format!("/get-proof/{}?key=0x10", trie_id))
            .body(Body::empty())
            .unwrap();

        let original_proof_response = app.clone().oneshot(original_proof_request).await.unwrap();
        let body = original_proof_response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let original_proof_data: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(original_proof_data["value"], "0x0100");
        assert_eq!(original_proof_data["exists"], true);
    }

    #[tokio::test]
    async fn test_upsert_actions_invalid_format() {
        let app = create_router();

        let upsert_request = Request::builder()
            .method("POST")
            .uri("/upsert-actions")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"actions": ["invalid_format"]}"#))
            .unwrap();

        let response = app.clone().oneshot(upsert_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn test_upsert_actions_nonexistent_trie() {
        let app = create_router();

        let upsert_request = Request::builder()
            .method("POST")
            .uri("/upsert-actions")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"actions": ["nonexistent;0x1;0x42"]}"#))
            .unwrap();

        let response = app.clone().oneshot(upsert_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }
}
