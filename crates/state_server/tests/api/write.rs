use axum::Router;
use pathfinder_crypto::Felt;
use state_server::{
    create_router,
    mpt::{db::trie::TrieDB, trie::Trie},
    AppState,
};
use types::proofs::injected_state::StateProof;

use crate::helpers::{assert_write_proof, write_proof, write_to_trie};

async fn setup() -> anyhow::Result<(Router, AppState)> {
    let state = AppState::new(":memory:")?;
    Ok((create_router(state.clone()), state))
}

#[tokio::test]
async fn write_to_new_trie() {
    let (app, state) = setup().await.unwrap();
    let (label, key, val) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
    );
    let conn = state.get_connection().unwrap();
    let db = TrieDB::new(&conn);

    assert!(db.get_leaf_at(key, 0, label).unwrap().is_empty());
    let root = write_to_trie(&app, label, Felt::ZERO, key, val).await.trie_root;
    let proof = write_proof(&app, label, Felt::ZERO, key, val).await;

    assert_write_proof(&StateProof::Write(proof.clone()), key, Felt::ZERO, val, "new trie");
    assert_eq!((proof.trie_root_prev, proof.trie_root_post), (Felt::ZERO, root));
    assert_eq!(
        db.get_leaf_at(key, db.get_node_idx_by_hash(root, label).unwrap().unwrap(), label)
            .unwrap()
            .data
            .value,
        val
    );
}

#[tokio::test]
async fn write_to_existing_trie() {
    let (app, state) = setup().await.unwrap();
    let (label, k1, k2, v1, v2) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
    );
    let conn = state.get_connection().unwrap();
    let db = TrieDB::new(&conn);

    let root1 = write_to_trie(&app, label, Felt::ZERO, k1, v1).await.trie_root;
    assert_ne!(root1, Felt::ZERO, "Root must change after first write");
    let proof1 = write_proof(&app, label, Felt::ZERO, k1, v1).await;
    assert_write_proof(&StateProof::Write(proof1.clone()), k1, Felt::ZERO, v1, "first write");

    assert!(db
        .get_leaf_at(k2, db.get_node_idx_by_hash(root1, label).unwrap().unwrap(), label)
        .unwrap()
        .is_empty());
    let root2 = write_to_trie(&app, label, root1, k2, v2).await.trie_root;
    assert_ne!(root2, root1, "Root must change after second write");
    let proof2 = write_proof(&app, label, root1, k2, v2).await;
    assert_write_proof(&StateProof::Write(proof2.clone()), k2, Felt::ZERO, v2, "second write");

    let idx2 = db.get_node_idx_by_hash(root2, label).unwrap().unwrap();
    assert_eq!(
        (
            db.get_leaf_at(k1, idx2, label).unwrap().data.value,
            db.get_leaf_at(k2, idx2, label).unwrap().data.value
        ),
        (v1, v2)
    );
}

#[tokio::test]
async fn override_existing_key() {
    let (app, state) = setup().await.unwrap();
    let (label, key, v1, v2) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
    );
    let conn = state.get_connection().unwrap();
    let db = TrieDB::new(&conn);

    let root1 = write_to_trie(&app, label, Felt::ZERO, key, v1).await.trie_root;
    let proof1 = write_proof(&app, label, Felt::ZERO, key, v1).await;
    assert_write_proof(&StateProof::Write(proof1), key, Felt::ZERO, v1, "initial");

    let root2 = write_to_trie(&app, label, root1, key, v2).await.trie_root;
    let proof2 = write_proof(&app, label, root1, key, v2).await;
    assert_write_proof(&StateProof::Write(proof2.clone()), key, v1, v2, "override");
    assert_ne!(root1, root2, "Overwriting key should change the root");

    assert_eq!((proof2.trie_root_prev, proof2.trie_root_post), (root1, root2));
    assert!(!proof2.state_proof_prev.is_empty() && !proof2.state_proof_post.is_empty());
    assert_eq!(
        db.get_leaf_at(key, db.get_node_idx_by_hash(root2, label).unwrap().unwrap(), label)
            .unwrap()
            .data
            .value,
        v2
    );
}

#[tokio::test]
async fn multiple_key_overrides_with_proofs() {
    let (app, _) = setup().await.unwrap();
    let (label, key) = (Felt::from_hex_str("0x456").unwrap(), Felt::from_hex_str("0x10").unwrap());
    let values: Vec<Felt> = (0..100).map(|_| Felt::random(&mut rand::thread_rng())).collect();

    let (mut root, mut prev) = (Felt::ZERO, Felt::ZERO);
    for (i, &val) in values.iter().enumerate() {
        let new_root = write_to_trie(&app, label, root, key, val).await.trie_root;
        let proof = write_proof(&app, label, root, key, val).await;
        assert_write_proof(&StateProof::Write(proof.clone()), key, prev, val, &format!("iter{}", i));
        assert_eq!((proof.trie_root_prev, proof.trie_root_post), (root, new_root));
        (root, prev) = (new_root, val);
    }
}

#[tokio::test]
async fn non_sequential_proof_verification() {
    let (app, _) = setup().await.unwrap();
    let label = Felt::from_hex_str("0x789").unwrap();
    let (k1, k2, k3) = (
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x3").unwrap(),
    );
    let (v1, v2, v3) = (
        Felt::from_hex_str("0x100").unwrap(),
        Felt::from_hex_str("0x200").unwrap(),
        Felt::from_hex_str("0x300").unwrap(),
    );

    // Build sequential states
    let r0 = Felt::ZERO;
    let r1 = write_to_trie(&app, label, r0, k1, v1).await.trie_root;
    let r2 = write_to_trie(&app, label, r1, k2, v2).await.trie_root;
    let r3 = write_to_trie(&app, label, r2, k3, v3).await.trie_root;

    // Generate proofs in order: 1st, 2nd, 3rd for simplicity
    let proofs = [
        write_proof(&app, label, r0, k1, v1).await,
        write_proof(&app, label, r1, k2, v2).await,
        write_proof(&app, label, r2, k3, v3).await,
    ];
    let keys = [k1, k2, k3];
    let values = [v1, v2, v3];

    // Verify in multiple random orders
    for order in [[1, 2, 0], [2, 0, 1], [0, 1, 2], [2, 1, 0]] {
        for &i in &order {
            let p = &proofs[i];
            assert_write_proof(&StateProof::Write(p.clone()), keys[i], Felt::ZERO, values[i], &format!("rand{}", i));
            assert!(
                Trie::verify_proof(
                    &p.state_proof_post
                        .iter()
                        .map(|n| (n.clone().into(), Felt::ZERO))
                        .collect::<Vec<_>>(),
                    p.trie_root_post,
                    p.leaf_post
                ) == Some(state_server::mpt::trie::Membership::Member)
            );
        }
    }

    // Verify state transitions
    assert_eq!(
        [
            (proofs[0].trie_root_prev, proofs[0].trie_root_post),
            (proofs[1].trie_root_prev, proofs[1].trie_root_post),
            (proofs[2].trie_root_prev, proofs[2].trie_root_post)
        ],
        [(r0, r1), (r1, r2), (r2, r3)]
    );
}
