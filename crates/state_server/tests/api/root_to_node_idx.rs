use axum::{http::StatusCode, Router};
use http_body_util::BodyExt;
use pathfinder_crypto::Felt;
use serde_json::from_slice;
use state_server::{api::root_to_node_idx::GetIdResponse, create_router, AppState};

use crate::helpers::{create_trie, get_trie_root_node_idx};

async fn setup() -> anyhow::Result<Router> {
    Ok(create_router(AppState::new_memory()?))
}

/// Tests that a trie_root of zero returns a trie_root_node_idx of 0.
#[tokio::test]
async fn root_is_zero() {
    let app = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let trie_root = Felt::ZERO;

    let response = get_trie_root_node_idx(&app, trie_label, trie_root).await;
    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let response: GetIdResponse = from_slice(&body).unwrap();

    assert_eq!(response.trie_root_node_idx, 0, "Expected trie_root_node_idx to be 0 for zero root");
    assert_eq!(response.trie_root, trie_root);
}

/// Tests that a non-existent trie_root returns a 404.
#[tokio::test]
async fn root_not_found() {
    let app = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let trie_root = Felt::from_hex_str("0x456").unwrap();

    let response = get_trie_root_node_idx(&app, trie_label, trie_root).await;
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

/// Tests that an existing trie_root can be found.
#[tokio::test]
async fn root_found() {
    let app = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let keys = vec![Felt::from_hex_str("0x1").unwrap()];
    let values = vec![Felt::from_hex_str("0x1").unwrap()];

    let create_response = create_trie(&app, trie_label, keys, values).await;

    let response = get_trie_root_node_idx(&app, trie_label, create_response.trie_root).await;
    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let response: GetIdResponse = from_slice(&body).unwrap();

    assert!(response.trie_root_node_idx > 0);
    assert_eq!(response.trie_root, create_response.trie_root);
}

/// Tests that a trie_root cannot be found with the wrong label.
#[tokio::test]
async fn root_found_wrong_label() {
    let app = setup().await.unwrap();

    let trie_label_a = Felt::from_hex_str("0x123").unwrap();
    let keys = vec![Felt::from_hex_str("0x1").unwrap()];
    let values = vec![Felt::from_hex_str("0x1").unwrap()];

    let create_response = create_trie(&app, trie_label_a, keys, values).await;

    // Use a different label to ensure the root is not found
    let trie_label_b = Felt::from_hex_str("0x456").unwrap();

    let response = get_trie_root_node_idx(&app, trie_label_b, create_response.trie_root).await;
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}
