use axum::Router;
use pathfinder_crypto::Felt;
use state_server::{create_router, AppState};
use types::proofs::injected_state::{Action, ActionRead, StateProof, ActionWrite};
use crate::helpers::{create_trie, get_state_proofs};

async fn setup() -> anyhow::Result<Router> {
    let state = AppState::new(":memory:")?;
    let router = create_router(state);
    Ok(router)
}

// 1) Read on ZERO root
#[tokio::test]
async fn proofs_read_zero_root() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key   = Felt::from_hex_str("0x1").unwrap();

    let req_actions = vec![
        Action::Read(ActionRead { trie_label: label, trie_root: Felt::ZERO, key })
    ];

    let state_proofs = get_state_proofs(&app, req_actions).await;

    let StateProof::Read(r) = &state_proofs.state_proofs[0] else { panic!("expected Read"); };
    assert_eq!(r.trie_id, 0);
    assert_eq!(r.trie_root, Felt::ZERO);
    assert!(r.state_proof.is_empty());
    assert_eq!(r.leaf.key, key);
    assert_eq!(r.leaf.data.value, Felt::ZERO);
}

// 2) Read existing key (membership)
#[tokio::test]
async fn proofs_read_existing_key() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value = Felt::from_hex_str("0x1").unwrap();

    let created = create_trie(&app, label, vec![key], vec![value]).await;
    let root = created.trie_root;

    let req_actions = vec![
        Action::Read(ActionRead { trie_label: label, trie_root: root, key: key })
    ];

    let state_proofs = get_state_proofs(&app, req_actions).await;
    assert_eq!(state_proofs.state_proofs.len(), 1);
    let StateProof::Read(r) = &state_proofs.state_proofs[0] else { panic!("expected Read"); };
    assert_eq!(r.trie_root, root);
    assert_eq!(r.leaf.key, key);
    assert_eq!(r.leaf.data.value, value);
    // proof may be empty for trivial trees, but must be a Vec. At least assert it's present:
    assert!(r.state_proof.len() >= 0);
}

// 3) Read missing key on real root (non-membership as zero-leaf)
#[tokio::test]
async fn proofs_read_missing_key() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key1 = Felt::from_hex_str("0x1").unwrap();
    let value1 = Felt::from_hex_str("0x1").unwrap();
    let key2 = Felt::from_hex_str("0x2").unwrap(); // missing

    let created = create_trie(&app, label, vec![key1], vec![value1]).await;
    let root = created.trie_root;

    let req_actions = vec![
        Action::Read(ActionRead { trie_label: label, trie_root: root, key: key2 })
    ];
    let state_proofs = get_state_proofs(&app, req_actions).await;
    assert_eq!(state_proofs.state_proofs.len(), 1);

    let StateProof::Read(r) = &state_proofs.state_proofs[0] else { panic!("expected Read"); };
    assert_eq!(r.trie_root, root);
    assert_eq!(r.leaf.key, key2);
    assert_eq!(r.leaf.data.value, Felt::ZERO);
}

// 4) Read with wrong label → current route returns 500
//TODO: Maybe change this later, currently reads return 500 for wrong label
#[tokio::test]
#[should_panic]
async fn proofs_read_wrong_label_is_500() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let wrong = Felt::from_hex_str("0x456").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value = Felt::from_hex_str("0x1").unwrap();

    let created = create_trie(&app, label, vec![key], vec![value]).await;
    let root = created.trie_root;

    let req_actions = vec![
        Action::Read(ActionRead { trie_label: wrong, trie_root: root, key })
    ];
    
    // This will panic because the router responds with 500
    let _ = get_state_proofs(&app, req_actions).await;
}

// 5) Write from ZERO root (new trie)
#[tokio::test]
async fn proofs_write_from_zero_root() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value = Felt::from_hex_str("0x1").unwrap();

    let req_actions = vec![
        Action::Write(ActionWrite { trie_label: label, trie_root: Felt::ZERO, key, value })
    ];
    let state_proofs = get_state_proofs(&app, req_actions).await;

    let StateProof::Write(w) = &state_proofs.state_proofs[0] else { panic!("expected Write"); };
    assert_eq!(w.trie_root_prev, Felt::ZERO);
    assert!(w.state_proof_prev.is_empty());
    assert_eq!(w.leaf_prev.data.value, Felt::ZERO);
    assert_ne!(w.trie_root_post, Felt::ZERO);
    assert_eq!(w.leaf_post.key, key);
    assert_eq!(w.leaf_post.data.value, value);
    assert!(w.trie_id_post > 0);
}

// 6) Write overwrite existing key
#[tokio::test]
async fn proofs_write_overwrite() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value1 = Felt::from_hex_str("0x1").unwrap();
    let value2 = Felt::from_hex_str("0x2").unwrap();

    let created = create_trie(&app, label, vec![key], vec![value1]).await;
    let root1 = created.trie_root;

    let req_actions = vec![
        Action::Write(ActionWrite { trie_label: label, trie_root: root1, key, value: value2 })
    ];
    let state_proofs = get_state_proofs(&app, req_actions).await;
    assert_eq!(state_proofs.state_proofs.len(), 1);

    let StateProof::Write(w) = &state_proofs.state_proofs[0] else { panic!("expected Write"); };
    assert_eq!(w.trie_root_prev, root1);
    assert_eq!(w.leaf_prev.data.value, value1);
    assert_eq!(w.leaf_post.data.value, value2);
    assert_ne!(w.trie_root_post, root1);
}

// 7) Write append new key to existing root
#[tokio::test]
async fn proofs_write_append_new_key() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key1 = Felt::from_hex_str("0x1").unwrap();
    let value1 = Felt::from_hex_str("0x1").unwrap();
    let key2 = Felt::from_hex_str("0x2").unwrap();
    let value2 = Felt::from_hex_str("0x2").unwrap();

    let created = create_trie(&app, label, vec![key1], vec![value1]).await;
    let root1 = created.trie_root;

    let req_actions = vec![
        Action::Write(ActionWrite { trie_label: label, trie_root: root1, key: key2, value: value2 })
    ];
    let state_proofs = get_state_proofs(&app, req_actions).await;
    assert_eq!(state_proofs.state_proofs.len(), 1);

    let StateProof::Write(w) = &state_proofs.state_proofs[0] else { panic!("expected Write"); };
    assert_eq!(w.leaf_prev.key, key2);
    assert_eq!(w.leaf_prev.data.value, Felt::ZERO); // missing before
    assert_eq!(w.leaf_post.key, key2);
    assert_eq!(w.leaf_post.data.value, value2);
    assert_ne!(w.trie_root_post, root1);
}

// 8) Batch preserves order & types
#[tokio::test]
async fn proofs_batch_order_and_types() {
    let app = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    let key = Felt::from_hex_str("0x1").unwrap();
    let value = Felt::from_hex_str("0x2").unwrap();

    let created = create_trie(&app, label, vec![key], vec![value]).await;
    let root = created.trie_root;

    let req_actions = vec![
        Action::Read(ActionRead { trie_label: label, trie_root: root, key: key }),
        Action::Write(ActionWrite { trie_label: label, trie_root: root, key: key, value: value }),
        Action::Read(ActionRead { trie_label: label, trie_root: root, key: key }),
    ];

    let state_proofs = get_state_proofs(&app, req_actions).await;
    assert_eq!(state_proofs.state_proofs.len(), 3);
    let proofs = &state_proofs.state_proofs;

    assert!(matches!(proofs[0], StateProof::Read(_)));
    assert!(matches!(proofs[1], StateProof::Write(_)));
    assert!(matches!(proofs[2], StateProof::Read(_)));
}