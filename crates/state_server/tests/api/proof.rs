use axum::Router;
use pathfinder_crypto::Felt;
use state_server::{
    create_router,
    mpt::trie::{Membership, Trie},
    AppState,
};
use types::proofs::injected_state::{Action, StateProof, StateProofRead};

use crate::helpers::{
    assert_read_membership_strict, assert_read_proof, assert_write_proof, build_trie, get_state_proofs, read_actions, write_actions,
    write_to_trie,
};

async fn setup() -> anyhow::Result<(Router, AppState)> {
    Ok((create_router(AppState::new(":memory:")?), AppState::new(":memory:")?))
}

#[tokio::test]
async fn get_state_proofs_single_trie_test() {
    let (app, _) = setup().await.unwrap();
    let label = Felt::from_hex_str("0x123").unwrap();
    // Deterministic keys; seeded values
    use rand::{rngs::StdRng, Rng, SeedableRng};
    let mut rng = StdRng::seed_from_u64(1);
    let kv: Vec<(Felt, Felt)> = (0..100).map(|i| (Felt::from(i as u64), Felt::from(rng.gen::<u64>()))).collect();

    let (mut proofs, mut root) = (Vec::new(), Felt::ZERO);
    for (k, v) in &kv {
        let _ = write_to_trie(&app, label, root, *k, *v).await;
        let response = get_state_proofs(&app, write_actions(label, root, vec![(*k, *v)])).await;
        if let StateProof::Write(p) = &response.state_proofs[0] {
            proofs.push(p.clone());
            root = p.trie_root_post;
        }
    }

    for (i, p) in proofs.iter().enumerate() {
        assert_write_proof(
            &StateProof::Write(p.clone()),
            kv[i].0,
            if i == 0 { Felt::ZERO } else { Felt::ZERO },
            kv[i].1,
            &format!("w{}", i),
        );
        assert!(
            Trie::verify_proof(
                &p.state_proof_post
                    .iter()
                    .map(|n| (n.clone().into(), Felt::ZERO))
                    .collect::<Vec<_>>(),
                p.trie_root_post,
                p.leaf_post
            ) == Some(Membership::Member)
        );
    }
}

/// Tests state proofs across multiple different tries to ensure no data collision.
#[tokio::test]
async fn get_state_proofs_multiple_tries_test() {
    let (app, _state) = setup().await.unwrap();

    // Create three different trie labels
    let trie_label_a = Felt::from_hex_str("0xAAA").unwrap();
    let trie_label_b = Felt::from_hex_str("0xBBB").unwrap();
    let trie_label_c = Felt::from_hex_str("0xCCC").unwrap();

    // Same keys but different values for each trie
    let key1 = Felt::from_hex_str("0x1").unwrap();
    let key2 = Felt::from_hex_str("0x2").unwrap();
    let key3 = Felt::from_hex_str("0x3").unwrap();

    // Values for trie A
    let value_a1 = Felt::from_hex_str("0xA01").unwrap();
    let value_a2 = Felt::from_hex_str("0xA02").unwrap();
    let value_a3 = Felt::from_hex_str("0xA03").unwrap();

    // Values for trie B
    let value_b1 = Felt::from_hex_str("0xB01").unwrap();
    let value_b2 = Felt::from_hex_str("0xB02").unwrap();

    // Values for trie C
    let value_c1 = Felt::from_hex_str("0xC01").unwrap();

    // 1. Build tries using helper function
    let root_a = build_trie(&app, trie_label_a, vec![(key1, value_a1), (key2, value_a2), (key3, value_a3)]).await;
    let root_b = build_trie(&app, trie_label_b, vec![(key1, value_b1), (key2, value_b2)]).await;
    let root_c = build_trie(&app, trie_label_c, vec![(key1, value_c1)]).await;

    // 4. Test reading from multiple tries in a single call
    let mut mixed_trie_actions = Vec::new();
    mixed_trie_actions.extend(read_actions(trie_label_a, root_a, vec![key1, key2, key3]));
    mixed_trie_actions.extend(read_actions(trie_label_b, root_b, vec![key1, key2, key3]));
    mixed_trie_actions.extend(read_actions(trie_label_c, root_c, vec![key1, key2]));

    let response = get_state_proofs(&app, mixed_trie_actions).await;
    assert_eq!(response.state_proofs.len(), 8);

    // Verify each proof using helper function
    let expected = [
        (key1, value_a1),
        (key2, value_a2),
        (key3, value_a3),
        (key1, value_b1),
        (key2, value_b2),
        (key3, Felt::ZERO),
        (key1, value_c1),
        (key2, Felt::ZERO),
    ];
    for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
        assert_read_proof(proof, key, value, &format!("multi-trie {}", i));
    }

    // Test write proofs across multiple tries
    let writes = [
        (
            trie_label_a,
            root_a,
            Felt::from_hex_str("0x4").unwrap(),
            Felt::from_hex_str("0xA04").unwrap(),
        ),
        (trie_label_b, root_b, key3, Felt::from_hex_str("0xB03").unwrap()),
    ];

    // Perform writes first, then get proofs
    for (label, root, key, value) in &writes {
        let _ = write_to_trie(&app, *label, *root, *key, *value).await;
    }
    let write_actions: Vec<Action> = writes
        .iter()
        .flat_map(|(l, r, k, v)| write_actions(*l, *r, vec![(*k, *v)]))
        .collect();
    let write_response = get_state_proofs(&app, write_actions).await;

    for (i, proof) in write_response.state_proofs.iter().enumerate() {
        assert_write_proof(proof, writes[i].2, Felt::ZERO, writes[i].3, &format!("write {}", i));
    }
}

/// Tests proof verification across multiple tries to ensure proofs are valid.
#[tokio::test]
async fn verify_proofs_multiple_tries_test() {
    let (app, _state) = setup().await.unwrap();

    // Create two different tries with overlapping keys but different values
    let trie_label_x = Felt::from_hex_str("0x111").unwrap();
    let trie_label_y = Felt::from_hex_str("0x222").unwrap();

    let key1 = Felt::from_hex_str("0x100").unwrap();
    let key2 = Felt::from_hex_str("0x200").unwrap();

    let value_x1 = Felt::from_hex_str("0x1001").unwrap();
    let value_x2 = Felt::from_hex_str("0x1002").unwrap();
    let value_y1 = Felt::from_hex_str("0x2001").unwrap();
    let value_y2 = Felt::from_hex_str("0x2002").unwrap();

    // Build both tries
    let root_x = build_trie(&app, trie_label_x, vec![(key1, value_x1), (key2, value_x2)]).await;
    let root_y = build_trie(&app, trie_label_y, vec![(key1, value_y1), (key2, value_y2)]).await;

    // Get proofs for both tries
    let mut actions = read_actions(trie_label_x, root_x, vec![key1, key2]);
    actions.extend(read_actions(trie_label_y, root_y, vec![key1, key2]));

    let response = get_state_proofs(&app, actions).await;
    assert_eq!(response.state_proofs.len(), 4);

    // Verify each proof
    let expected = [value_x1, value_x2, value_y1, value_y2];
    let keys = [key1, key2, key1, key2];
    for (i, (proof, (&expected_value, &expected_key))) in response.state_proofs.iter().zip(expected.iter().zip(keys.iter())).enumerate() {
        assert_read_proof(proof, expected_key, expected_value, &format!("cross-trie {}", i));
        if let StateProof::Read(StateProofRead { state_proof, .. }) = proof {
            assert!(!state_proof.is_empty(), "Proof should not be empty at {}", i);
        }
    }

    // Test cross-trie proof isolation
    if let (StateProof::Read(proof_x), StateProof::Read(proof_y)) = (&response.state_proofs[0], &response.state_proofs[2]) {
        assert_ne!(proof_x.trie_root, proof_y.trie_root, "Different tries should have different roots");
    }
}
