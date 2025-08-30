use axum::{http::StatusCode, Router};
use state_server::{create_router, AppState};

use crate::helpers::{create_trie, read_from_trie};
use pathfinder_crypto::Felt;


async fn setup() -> anyhow::Result<Router> {
    let state = AppState::new(":memory:")?;
    let router = create_router(state.clone());
    Ok(router)
}

#[tokio::test]
async fn read_from_existing_trie() {
    let app = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let keys  = vec![Felt::from_hex_str("0x1").unwrap()];
    let values = vec![Felt::from_hex_str("0x1").unwrap()];

    let created = create_trie(&app, trie_label, keys.clone(), values.clone()).await;
    let trie_root = created.trie_root; 

    let read = read_from_trie(&app, trie_label, trie_root, keys[0]).await;

    assert_eq!(read.key, keys[0]);
    assert_eq!(read.value, values[0]);
}

#[tokio::test]
#[should_panic] 
//TODO: Maybe change this later, currently reads return 500 for wrong label
async fn read_from_unexisting_trie() {
    let app = setup().await.unwrap();

    let label_ok = Felt::from_hex_str("0x123").unwrap();
    let key      = Felt::from_hex_str("0x1").unwrap();
    let value    = Felt::from_hex_str("0x1").unwrap();

    // Seed a trie with the correct label
    let created   = create_trie(&app, label_ok, vec![key], vec![value]).await;
    let trie_root = created.trie_root;

    // Try reading with a label that does not exist for this root
    let wrong_label = Felt::from_hex_str("0x456").unwrap();

    // This will panic inside the helper because it asserts status == 200 but gets 500.
    let _ = read_from_trie(&app, wrong_label, trie_root, key).await;
}

#[tokio::test]
async fn read_unexisting_key_from_existing_trie() {
    let app = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value = Felt::from_hex_str("0x1").unwrap();

    let created = create_trie(&app, trie_label, vec![key], vec![value]).await;
    let trie_root = created.trie_root; 

    let false_key = Felt::from_hex_str("0x2").unwrap();
    let read = read_from_trie(&app, trie_label, trie_root, false_key).await;

    assert_eq!(read.key, false_key);
    assert_eq!(read.value, Felt::ZERO);
}
