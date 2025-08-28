use axum::{
    body::Body,
    http::{Request, StatusCode},
    Router,
};
use http_body_util::BodyExt;
use pathfinder_crypto::Felt;
use serde_json::from_slice;
use state_server::api::{
    create_trie::{CreateTrieRequest, CreateTrieResponse},
    write::WriteResponse,
};
use tower::ServiceExt;

pub async fn create_trie(app: &Router, trie_label: Felt, keys: Vec<Felt>, values: Vec<Felt>) -> CreateTrieResponse {
    let create_payload = CreateTrieRequest { trie_label, keys, values };

    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/create_trie")
                .header("content-type", "application/json")
                .body(Body::from(serde_json::to_vec(&create_payload).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
    let body = response.into_body().collect().await.unwrap().to_bytes();
    from_slice(&body).unwrap()
}

pub async fn write_to_trie(app: &Router, trie_label: Felt, trie_root: Felt, key: Felt, value: Felt) -> WriteResponse {
    let response = app
        .clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(format!(
                    "/write?trie_label={}&trie_root={}&key={}&value={}",
                    trie_label, trie_root, key, value
                ))
                .header("content-type", "application/json")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
    let body = response.into_body().collect().await.unwrap().to_bytes();
    from_slice(&body).unwrap()
}

pub async fn get_trie_root_node_idx(app: &Router, trie_label: Felt, trie_root: Felt) -> axum::http::Response<axum::body::Body> {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/get_trie_root_node_idx?trie_label={}&trie_root={}", trie_label, trie_root))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap()
}
