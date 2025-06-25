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
use tracing::info;
use uuid;

pub mod merkle_tree;

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
        let (storage, mut trie) = Trie::load(self.root_idx, &conn);

        // Convert key and value to Felt
        let key_felt = self.string_to_felt(&key)?;
        let value_felt = self.string_to_felt(&value)?;

        // Create a new leaf with the key-value pair
        let leaf = TrieLeaf::new(key_felt, false, value_felt);

        // Set the leaf in the trie
        trie.set(&storage, leaf.get_path(), leaf.commitment())?;

        // Commit the changes
        let update = trie.commit(&storage)?;
        Trie::persist_updates(&storage, &update, &vec![leaf])?;

        // Update our root hash and index
        self.root_hash = update.root_commitment;
        self.root_idx = pathfinder_storage::TrieStorageIndex::from(storage.get_node_idx_by_hash(update.root_commitment)?.unwrap());

        Ok(())
    }

    pub fn get(&self, key: &str) -> Option<String> {
        if let Ok(conn) = self.db_connection_manager.get_connection() {
            let storage = TrieDB::new(&conn);
            if let Ok(key_felt) = self.string_to_felt(key) {
                if let Ok(leaf) = storage.get_leaf(key_felt) {
                    // Check if the leaf has actual data (non-zero voting power)
                    if leaf.data.voting_power != pathfinder_crypto::Felt::ZERO {
                        return Some(self.felt_to_string(leaf.data.voting_power));
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
                if leaf.data.voting_power == pathfinder_crypto::Felt::ZERO {
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
            return Err(StatusCode::BAD_REQUEST);
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

// Router setup
pub fn create_router() -> Router {
    let state = AppState::new();

    Router::new()
        .route("/new-trie", post(new_trie))
        .route("/update-trie/:trie_id", post(update_trie))
        .route("/get-root-hash/:trie_id", get(get_root_hash))
        .route("/get-proof/:trie_id", get(get_proof))
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
            .layer(CorsLayer::permissive())
            .layer(TraceLayer::new_for_http())
            .with_state(state)
    }

    #[tokio::test]
    async fn test_new_trie_with_id() {
        let app = create_router();

        let request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();

        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: serde_json::Value = serde_json::from_str(&response_text).unwrap();

        assert_eq!(response_body["trie_id"], "test-trie");
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

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        let create_response = app.oneshot(create_request).await.unwrap();
        assert_eq!(create_response.status(), StatusCode::OK);

        // Now update the trie
        let app = create_test_router_with_state(state);
        let update_request = Request::builder()
            .method("POST")
            .uri("/update-trie/test-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(update_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();

        let response_text = String::from_utf8(body_bytes.to_vec()).unwrap();
        let response_body: serde_json::Value = serde_json::from_str(&response_text).unwrap();

        assert_eq!(response_body["trie_id"], "test-trie");
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

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Now try to update with invalid key
        let app = create_test_router_with_state(state);
        let update_request = Request::builder()
            .method("POST")
            .uri("/update-trie/test-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "invalid_key", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(update_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn test_update_trie_empty_key() {
        let state = AppState::new();

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Now try to update with empty key
        let app = create_test_router_with_state(state);
        let update_request = Request::builder()
            .method("POST")
            .uri("/update-trie/test-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "", "value": "0x42"}"#))
            .unwrap();

        let response = app.oneshot(update_request).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn test_get_root_hash_success() {
        let state = AppState::new();

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Now get the root hash
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri("/get-root-hash/test-trie")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], "test-trie");
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

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Update the trie with some data
        let app = create_test_router_with_state(state.clone());
        let update_request = Request::builder()
            .method("POST")
            .uri("/update-trie/test-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"key": "0x1", "value": "0x42"}"#))
            .unwrap();

        app.oneshot(update_request).await.unwrap();

        // Now get the proof
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri("/get-proof/test-trie?key=0x1")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], "test-trie");
        assert_eq!(response_body["key"], "0x1");
        assert!(!response_body["value"].is_null());
        assert_eq!(response_body["value"], "0x42");
        assert!(!response_body["proof"].as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_get_proof_nonexistent_key() {
        let state = AppState::new();

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Try to get proof for non-existent key
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri("/get-proof/test-trie?key=0x999")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        let body = response.into_body();
        let body_bytes = axum::body::to_bytes(body, usize::MAX).await.unwrap();
        let response_body: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();

        assert_eq!(response_body["trie_id"], "test-trie");
        assert_eq!(response_body["key"], "0x999");
        assert!(response_body["value"].is_null());
        assert!(response_body["proof"].as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn test_get_proof_invalid_key() {
        let state = AppState::new();

        // First create a trie
        let app = create_test_router_with_state(state.clone());
        let create_request = Request::builder()
            .method("POST")
            .uri("/new-trie")
            .header("content-type", "application/json")
            .body(Body::from(r#"{"id": "test-trie"}"#))
            .unwrap();

        app.oneshot(create_request).await.unwrap();

        // Try to get proof with invalid key
        let app = create_test_router_with_state(state);
        let request = Request::builder()
            .method("GET")
            .uri("/get-proof/test-trie?key=invalid_key")
            .body(Body::empty())
            .unwrap();

        let response = app.oneshot(request).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
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
}
