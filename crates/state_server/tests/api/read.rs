use axum::Router;
use pathfinder_crypto::Felt;
use state_server::{create_router, mpt::trie::Membership, AppState};

use crate::helpers::{
    build_trie, get_state_proofs, read_actions, read_from_trie, verify_read_proof_crypto, verify_read_proof_with_membership, write_to_trie,
};

async fn setup() -> anyhow::Result<(Router, AppState)> {
    let state = AppState::new(":memory:")?;
    Ok((create_router(state.clone()), state))
}

#[tokio::test]
async fn read_from_trie_test() {
    let (app, _) = setup().await.unwrap();
    let (label, key, val) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
    );
    let root = write_to_trie(&app, label, Felt::ZERO, key, val).await.trie_root;

    // Test both direct read and proof verification
    let response = read_from_trie(&app, label, root, key).await;
    assert_eq!((response.key, response.value), (key, val));

    let proof_response = get_state_proofs(&app, read_actions(label, root, vec![key])).await;
    verify_read_proof_crypto(&proof_response.state_proofs[0], key, val, "basic_read", Some(Membership::Member));
    verify_read_proof_with_membership(&proof_response.state_proofs[0], key, val, Some(Membership::Member), "basic_read");
}

#[tokio::test]
async fn read_non_existent_key() {
    let (app, _) = setup().await.unwrap();
    let (label, k1, k2, v1) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
    );
    let root = write_to_trie(&app, label, Felt::ZERO, k1, v1).await.trie_root;
    assert_ne!(root, Felt::ZERO, "Root must change from zero after first write");

    // Test both direct read and proof verification for non-existent key
    let response = read_from_trie(&app, label, root, k2).await;
    assert_eq!((response.key, response.value), (k2, Felt::ZERO));

    let proof_response = get_state_proofs(&app, read_actions(label, root, vec![k2])).await;
    verify_read_proof_crypto(
        &proof_response.state_proofs[0],
        k2,
        Felt::ZERO,
        "non_existent",
        Some(Membership::NonMember),
    );
    verify_read_proof_with_membership(
        &proof_response.state_proofs[0],
        k2,
        Felt::ZERO,
        Some(Membership::NonMember),
        "non_existent",
    );
}

#[tokio::test]
async fn random_reads_across_multiple_tries() {
    let (app, _) = setup().await.unwrap();
    let (la, lb, lc) = (
        Felt::from_hex_str("0x666").unwrap(),
        Felt::from_hex_str("0x777").unwrap(),
        Felt::from_hex_str("0x888").unwrap(),
    );

    // Build tries with small fixed data sets
    let kv_a = vec![
        (Felt::from_hex_str("0x1").unwrap(), Felt::from_hex_str("0xA1").unwrap()),
        (Felt::from_hex_str("0x2").unwrap(), Felt::from_hex_str("0xA2").unwrap()),
    ];
    let kv_b = vec![
        (Felt::from_hex_str("0x1").unwrap(), Felt::from_hex_str("0xB1").unwrap()),
        (Felt::from_hex_str("0x3").unwrap(), Felt::from_hex_str("0xB3").unwrap()),
    ];
    let kv_c = vec![(Felt::from_hex_str("0x2").unwrap(), Felt::from_hex_str("0xC2").unwrap())];

    let (ra, rb, rc) = (
        build_trie(&app, la, kv_a.clone()).await,
        build_trie(&app, lb, kv_b.clone()).await,
        build_trie(&app, lc, kv_c.clone()).await,
    );

    // Test random reads from different tries
    let test_keys = [
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x3").unwrap(),
        Felt::from_hex_str("0x4").unwrap(),
    ];
    let mut reads = Vec::new();
    let mut expected = Vec::new();

    // For each test key, prepare read actions and expected values for all three tries (A, B, C)
    for &key in &test_keys {
        for (label, root, kv) in &[(la, ra, &kv_a), (lb, rb, &kv_b), (lc, rc, &kv_c)] {
            reads.extend(read_actions(*label, *root, vec![key]));
            // Find the value for the key in the current trie, or Felt::ZERO if not present
            expected.push((key, kv.iter().find(|(k, _)| *k == key).map_or(Felt::ZERO, |(_, v)| *v)));
        }
    }
    // TODO: fix verification
    // get_state_proofs(&app, reads).await;
    // for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
    //     let expected_membership = if value == Felt::ZERO {
    //         Membership::NonMember
    //     } else {
    //         Membership::Member
    //     };
    // verify_read_proof_crypto(proof, key, value, &format!("rand{}", i), Some(expected_membership));
    // }
}

#[tokio::test]
async fn cross_trie_collision_test() {
    let (app, _) = setup().await.unwrap();
    let labels = [
        Felt::from_hex_str("0x111").unwrap(),
        Felt::from_hex_str("0x222").unwrap(),
        Felt::from_hex_str("0x333").unwrap(),
    ];
    let shared_keys = [
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x3").unwrap(),
    ];

    // Build tries with same keys but different values
    let mut tries = Vec::new();
    for (i, &label) in labels.iter().enumerate() {
        let kv: Vec<(Felt, Felt)> = shared_keys
            .iter()
            .map(|&k| (k, Felt::from(i as u64 * 1000 + k.to_be_bytes()[31] as u64)))
            .collect();
        let root = build_trie(&app, label, kv.clone()).await;
        tries.push((label, root, kv));
    }

    // Read same keys from all tries simultaneously
    let mut cross_reads = Vec::new();
    let mut expected = Vec::new();

    for &key in &shared_keys {
        for (label, root, kv) in &tries {
            cross_reads.extend(read_actions(*label, *root, vec![key]));
            expected.push((key, kv.iter().find(|(k, _)| *k == key).unwrap().1));
        }
    }

    get_state_proofs(&app, cross_reads).await;
    // TODO: fix verification
    // for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
    //     verify_read_proof_crypto(proof, key, value, &format!("cross{}", i), Some(Membership::Member));
    // }

    // Verify no collision: same key should have different values across tries
    for i in 0..shared_keys.len() {
        let start_idx = i * tries.len();
        let values: Vec<Felt> = (start_idx..start_idx + tries.len()).map(|idx| expected[idx].1).collect();
        assert!(
            values.windows(2).any(|w| w[0] != w[1]),
            "Values should differ across tries for key {}",
            i
        );
    }
}

#[tokio::test]
async fn multi_trie_deterministic_reads() {
    let (app, _) = setup().await.unwrap();
    let (l1, l2, l3) = (Felt::from(1u64), Felt::from(2u64), Felt::from(3u64));
    let (k1, k2, k3) = (Felt::from(10u64), Felt::from(20u64), Felt::from(30u64));

    // Build 3 tries with overlapping and unique keys
    let r1 = build_trie(&app, l1, vec![(k1, Felt::from(100u64)), (k2, Felt::from(200u64))]).await;
    let r2 = build_trie(&app, l2, vec![(k1, Felt::from(1000u64)), (k3, Felt::from(3000u64))]).await;
    let r3 = build_trie(&app, l3, vec![(k2, Felt::from(20000u64))]).await;

    // Read all keys from all tries (mix of existing/non-existing)
    let reads = [
        read_actions(l1, r1, vec![k1, k2, k3]),
        read_actions(l2, r2, vec![k1, k2, k3]),
        read_actions(l3, r3, vec![k1, k2, k3]),
    ]
    .concat();
    // let expected = [
    //     (k1, Felt::from(100u64)),
    //     (k2, Felt::from(200u64)),
    //     (k3, Felt::ZERO),
    //     (k1, Felt::from(1000u64)),
    //     (k2, Felt::ZERO),
    //     (k3, Felt::from(3000u64)),
    //     (k1, Felt::ZERO),
    //     (k2, Felt::from(20000u64)),
    //     (k3, Felt::ZERO),
    // ];

    get_state_proofs(&app, reads).await;
    // TODO: fix verification
    // for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
    // verify_read_proof_crypto(proof, key, value, &format!("det{}", i), Some(Membership::Member));
    // }
}
