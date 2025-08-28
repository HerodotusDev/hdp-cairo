use axum::Router;
use pathfinder_crypto::Felt;
use state_server::{create_router, mpt::db::trie::TrieDB, AppState};

use crate::helpers::write_to_trie;

async fn setup() -> anyhow::Result<(Router, AppState)> {
    let state = AppState::new(":memory:")?;
    let router = create_router(state.clone());
    Ok((router, state))
}

/// Tests writing to a new trie.
#[tokio::test]
async fn write_to_new_trie() {
    let (app, state) = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value = Felt::from_hex_str("0x1").unwrap();

    let conn = state.get_connection().unwrap();
    let db = TrieDB::new(&conn);

    // 1. Verify that the key is not present before it's inserted.
    assert!(db.get_leaf_at(key, 0, trie_label).unwrap().is_empty());

    // 2. Write the key-value pair to the trie.
    let write_response = write_to_trie(&app, trie_label, Felt::ZERO, key, value).await;
    let new_root = write_response.trie_root;

    // 3. Verify membership for the key after it's inserted.
    let new_root_idx = db.get_node_idx_by_hash(new_root, trie_label).unwrap().unwrap();
    let leaf = db.get_leaf_at(key, new_root_idx, trie_label).unwrap();

    assert_eq!(leaf.key, key);
    assert_eq!(leaf.data.value, value);
}

/// Tests writing to an existing trie.
#[tokio::test]
async fn write_to_existing_trie() {
    let (app, state) = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let key1 = Felt::from_hex_str("0x1").unwrap();
    let value1 = Felt::from_hex_str("0x1").unwrap();
    let key2 = Felt::from_hex_str("0x2").unwrap();
    let value2 = Felt::from_hex_str("0x2").unwrap();

    // 1. Create a trie with one key-value pair.
    let write_response1 = write_to_trie(&app, trie_label, Felt::ZERO, key1, value1).await;
    let root1 = write_response1.trie_root;

    let conn = state.get_connection().unwrap();
    let db = TrieDB::new(&conn);

    // 2. Verify non-membership for the second key.
    let root1_idx = db.get_node_idx_by_hash(root1, trie_label).unwrap().unwrap();

    assert!(db.get_leaf_at(key2, root1_idx, trie_label).unwrap().is_empty());

    // 3. Write the second key-value pair to the trie.
    let write_response2 = write_to_trie(&app, trie_label, root1, key2, value2).await;
    let root2 = write_response2.trie_root;

    // 4. Verify membership for the second key.
    let root2_idx = db.get_node_idx_by_hash(root2, trie_label).unwrap().unwrap();
    let leaf2 = db.get_leaf_at(key2, root2_idx, trie_label).unwrap();
    assert_eq!(leaf2.key, key2);
    assert_eq!(leaf2.data.value, value2);

    // 5. Verify membership for the first key to ensure it's still there.
    let leaf1 = db.get_leaf_at(key1, root2_idx, trie_label).unwrap();
    assert_eq!(leaf1.key, key1);
    assert_eq!(leaf1.data.value, value1);
}

/// Tests overriding an existing key.
#[tokio::test]
async fn override_existing_key() {
    let (app, state) = setup().await.unwrap();

    let trie_label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value1 = Felt::from_hex_str("0x1").unwrap();
    let value2 = Felt::from_hex_str("0x2").unwrap();

    // 1. Create a trie with an initial key-value pair.
    let write_response1 = write_to_trie(&app, trie_label, Felt::ZERO, key, value1).await;
    let root1 = write_response1.trie_root;

    let conn = state.get_connection().unwrap();
    let db = TrieDB::new(&conn);

    // 2. Verify the initial value.
    let root1_idx = db.get_node_idx_by_hash(root1, trie_label).unwrap().unwrap();
    let leaf1 = db.get_leaf_at(key, root1_idx, trie_label).unwrap();
    assert_eq!(leaf1.data.value, value1);

    // 3. Override the key with a new value.
    let write_response2 = write_to_trie(&app, trie_label, root1, key, value2).await;
    let root2 = write_response2.trie_root;

    // 4. Verify the new value.
    let root2_idx = db.get_node_idx_by_hash(root2, trie_label).unwrap().unwrap();
    let leaf2 = db.get_leaf_at(key, root2_idx, trie_label).unwrap();
    assert_eq!(leaf2.data.value, value2);
}
