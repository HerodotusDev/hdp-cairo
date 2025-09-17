use pathfinder_crypto::Felt;
use state_server::mpt::trie::Membership;

use crate::helpers::{
    build_trie, get_state_proofs, read_actions, read_from_trie, setup, verify_read_proof_crypto, verify_read_proof_with_membership,
    write_to_trie,
};

#[tokio::test]
async fn read_from_trie_test() {
    let (router, _) = setup().await.unwrap();
    let (label, key, val) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
    );
    let root = write_to_trie(&router, label, Felt::ZERO, key, val).await.trie_root;

    // Test both direct read and proof verification
    let response = read_from_trie(&router, label, root, key).await;
    assert_eq!((response.key, response.value), (key, Some(val)));

    let proof_response = get_state_proofs(&router, read_actions(label, root, vec![key])).await;
    verify_read_proof_crypto(&proof_response.state_proofs[0], key, val, "basic_read", Some(Membership::Member));
    verify_read_proof_with_membership(&proof_response.state_proofs[0], key, val, Some(Membership::Member), "basic_read");
}

#[tokio::test]
async fn read_non_existent_key() {
    let (router, _) = setup().await.unwrap();
    let (label, k1, k2, v1) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
    );
    let root = write_to_trie(&router, label, Felt::ZERO, k1, v1).await.trie_root;
    assert_ne!(root, Felt::ZERO, "Root must change from zero after first write");

    // Test both direct read and proof verification for non-existent key
    let response = read_from_trie(&router, label, root, k2).await;
    assert_eq!((response.key, response.value), (k2, None));

    let proof_response = get_state_proofs(&router, read_actions(label, root, vec![k2])).await;
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
    let (router, _) = setup().await.unwrap();
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
        build_trie(&router, la, kv_a.clone()).await,
        build_trie(&router, lb, kv_b.clone()).await,
        build_trie(&router, lc, kv_c.clone()).await,
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
    let response = get_state_proofs(&router, reads).await;
    for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
        let expected_membership = if value == Felt::ZERO {
            Membership::NonMember
        } else {
            Membership::Member
        };
        verify_read_proof_crypto(proof, key, value, &format!("rand{}", i), Some(expected_membership));
    }
}

#[tokio::test]
async fn read_edge_cases() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x20_u64);

    // Test reading with zero key
    let zero_key = Felt::ZERO;
    let resp = get_state_proofs(&router, read_actions(label, Felt::ZERO, vec![zero_key])).await;
    assert_eq!(resp.state_proofs.len(), 1);

    match &resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.key, zero_key, "Should return zero key");
            assert_eq!(p.leaf.data.value, Felt::ZERO, "Zero key should return zero value from empty trie");
        }
        _ => panic!("Expected read proof for zero key"),
    }

    // Test reading with maximum key value
    let max_key = Felt::from_hex_str("0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff").unwrap();
    let resp_max = get_state_proofs(&router, read_actions(label, Felt::ZERO, vec![max_key])).await;
    assert_eq!(resp_max.state_proofs.len(), 1);

    match &resp_max.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.key, max_key, "Should return maximum key");
            assert_eq!(
                p.leaf.data.value,
                Felt::ZERO,
                "Maximum key should return zero value from empty trie"
            );
        }
        _ => panic!("Expected read proof for maximum key"),
    }
}

#[tokio::test]
async fn read_sequential_key_patterns() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x21_u64);

    // Test reading sequential keys
    let sequential_keys: Vec<Felt> = (0..10).map(|i| Felt::from(i as u64)).collect();
    let sequential_values: Vec<Felt> = (100..110).map(|i| Felt::from(i as u64)).collect();

    // Build trie with sequential keys
    let mut current_root = Felt::ZERO;
    for (key, value) in sequential_keys.iter().zip(sequential_values.iter()) {
        current_root = write_to_trie(&router, label, current_root, *key, *value).await.trie_root;
    }

    // Read all sequential keys
    let read_resp = get_state_proofs(&router, read_actions(label, current_root, sequential_keys.clone())).await;
    assert_eq!(read_resp.state_proofs.len(), sequential_keys.len());

    // Verify each key-value pair
    for (i, (expected_key, expected_value)) in sequential_keys.iter().zip(sequential_values.iter()).enumerate() {
        match &read_resp.state_proofs[i] {
            types::proofs::injected_state::StateProof::Read(p) => {
                assert_eq!(p.leaf.key, *expected_key, "Sequential key {} should match", i);
                assert_eq!(p.leaf.data.value, *expected_value, "Sequential value {} should match", i);
            }
            _ => panic!("Expected read proof for sequential key {}", i),
        }
    }
}

#[tokio::test]
async fn read_sparse_key_distribution() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x22_u64);

    // Test reading with sparse key distribution (keys far apart)
    let sparse_keys = vec![
        Felt::from(1u64),
        Felt::from(1000u64),
        Felt::from(1000000u64),
        Felt::from(1000000000u64),
    ];
    let sparse_values = vec![
        Felt::from(0x111u64),
        Felt::from(0x222u64),
        Felt::from(0x333u64),
        Felt::from(0x444u64),
    ];

    // Build trie with sparse keys
    let mut current_root = Felt::ZERO;
    for (key, value) in sparse_keys.iter().zip(sparse_values.iter()) {
        current_root = write_to_trie(&router, label, current_root, *key, *value).await.trie_root;
    }

    // Read all sparse keys
    let read_resp = get_state_proofs(&router, read_actions(label, current_root, sparse_keys.clone())).await;
    assert_eq!(read_resp.state_proofs.len(), sparse_keys.len());

    // Verify each sparse key-value pair
    for (i, (expected_key, expected_value)) in sparse_keys.iter().zip(sparse_values.iter()).enumerate() {
        match &read_resp.state_proofs[i] {
            types::proofs::injected_state::StateProof::Read(p) => {
                assert_eq!(p.leaf.key, *expected_key, "Sparse key {} should match", i);
                assert_eq!(p.leaf.data.value, *expected_value, "Sparse value {} should match", i);
            }
            _ => panic!("Expected read proof for sparse key {}", i),
        }
    }
}

#[tokio::test]
async fn read_mixed_existing_non_existing() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x23_u64);

    // Test reading a mix of existing and non-existing keys
    let existing_key = Felt::from(0x123u64);
    let existing_value = Felt::from(0x456u64);
    let non_existing_key = Felt::from(0x789u64);

    // Write only one key
    let root = write_to_trie(&router, label, Felt::ZERO, existing_key, existing_value)
        .await
        .trie_root;

    // Read both existing and non-existing keys
    let mixed_keys = vec![existing_key, non_existing_key];
    let read_resp = get_state_proofs(&router, read_actions(label, root, mixed_keys)).await;
    assert_eq!(read_resp.state_proofs.len(), 2);

    // Check existing key
    match &read_resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.key, existing_key, "Existing key should be returned");
            assert_eq!(p.leaf.data.value, existing_value, "Existing key should return its value");
        }
        _ => panic!("Expected read proof for existing key"),
    }

    // Check non-existing key
    match &read_resp.state_proofs[1] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.key, non_existing_key, "Non-existing key should be returned");
            assert_eq!(p.leaf.data.value, Felt::ZERO, "Non-existing key should return zero");
        }
        _ => panic!("Expected read proof for non-existing key"),
    }
}

#[tokio::test]
async fn read_duplicate_keys() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x24_u64);

    // Test reading the same key multiple times in one request
    let key = Felt::from(0x123u64);
    let value = Felt::from(0x456u64);

    // Write the key
    let root = write_to_trie(&router, label, Felt::ZERO, key, value).await.trie_root;

    // Read the same key multiple times
    let duplicate_keys = vec![key, key, key, key];
    let read_resp = get_state_proofs(&router, read_actions(label, root, duplicate_keys)).await;
    assert_eq!(read_resp.state_proofs.len(), 4);

    // All should return the same value
    for (i, proof) in read_resp.state_proofs.iter().enumerate() {
        match proof {
            types::proofs::injected_state::StateProof::Read(p) => {
                assert_eq!(p.leaf.key, key, "Duplicate key {} should match", i);
                assert_eq!(p.leaf.data.value, value, "Duplicate key {} should return same value", i);
            }
            _ => panic!("Expected read proof for duplicate key {}", i),
        }
    }
}

#[tokio::test]
async fn read_empty_key_list() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x25_u64);

    // Test reading with empty key list
    let empty_keys: Vec<Felt> = vec![];
    let resp = get_state_proofs(&router, read_actions(label, Felt::ZERO, empty_keys)).await;

    // Should return empty response
    assert_eq!(resp.state_proofs.len(), 0);
}

#[tokio::test]
async fn read_large_key_set() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x26_u64);

    // Test reading with a large number of keys
    let large_key_count = 100;
    let keys: Vec<Felt> = (0..large_key_count).map(|i| Felt::from(i as u64)).collect();
    let values: Vec<Felt> = (100..100 + large_key_count).map(|i| Felt::from(i as u64)).collect();

    // Build trie with many keys
    let mut current_root = Felt::ZERO;
    for (key, value) in keys.iter().zip(values.iter()) {
        current_root = write_to_trie(&router, label, current_root, *key, *value).await.trie_root;
    }

    // Read all keys at once
    let read_resp = get_state_proofs(&router, read_actions(label, current_root, keys.clone())).await;
    assert_eq!(read_resp.state_proofs.len(), large_key_count);

    // Verify a sample of the results
    let sample_indices = vec![0, 25, 50, 75, 99];
    for &idx in sample_indices.iter() {
        if idx < read_resp.state_proofs.len() {
            match &read_resp.state_proofs[idx] {
                types::proofs::injected_state::StateProof::Read(p) => {
                    let expected_key = Felt::from(idx as u64);
                    let expected_value = Felt::from((100 + idx) as u64);
                    assert_eq!(p.leaf.key, expected_key, "Large key set key {} should match", idx);
                    assert_eq!(p.leaf.data.value, expected_value, "Large key set value {} should match", idx);
                }
                _ => panic!("Expected read proof for large key set index {}", idx),
            }
        }
    }
}

#[tokio::test]
async fn cross_trie_collision_test() {
    let (router, _) = setup().await.unwrap();
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
        let root = build_trie(&router, label, kv.clone()).await;
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

    let expected_len = cross_reads.len();
    let response = get_state_proofs(&router, cross_reads).await;
    assert_eq!(response.state_proofs.len(), expected_len, "Should get one proof per read action");

    // Verify each proof using cryptographic validation
    for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
        let expected_membership = if value == Felt::ZERO {
            Membership::NonMember
        } else {
            Membership::Member
        };
        verify_read_proof_crypto(proof, key, value, &format!("cross{}", i), Some(expected_membership));
    }

    // Verify no collision: same key should have different values across tries
    for i in 0..shared_keys.len() {
        let start_idx = i * tries.len();
        let values: Vec<Felt> = (start_idx..start_idx + tries.len()).map(|idx| expected[idx].1).collect();

        // Check that values differ across tries for the same key
        for (j, window) in values.windows(2).enumerate() {
            assert_ne!(
                window[0], window[1],
                "Values should differ across tries for key {} at position {}",
                i, j
            );
        }
    }
}

#[tokio::test]
async fn multi_trie_deterministic_reads() {
    let (router, _) = setup().await.unwrap();
    let (l1, l2, l3) = (Felt::from(1u64), Felt::from(2u64), Felt::from(3u64));
    let (k1, k2, k3) = (Felt::from(10u64), Felt::from(20u64), Felt::from(30u64));

    // Build 3 tries with overlapping and unique keys
    let r1 = build_trie(&router, l1, vec![(k1, Felt::from(100u64)), (k2, Felt::from(200u64))]).await;
    let r2 = build_trie(&router, l2, vec![(k1, Felt::from(1000u64)), (k3, Felt::from(3000u64))]).await;
    let r3 = build_trie(&router, l3, vec![(k2, Felt::from(20000u64))]).await;

    // Read all keys from all tries (mix of existing/non-existing)
    let reads = [
        read_actions(l1, r1, vec![k1, k2, k3]),
        read_actions(l2, r2, vec![k1, k2, k3]),
        read_actions(l3, r3, vec![k1, k2, k3]),
    ]
    .concat();

    let response = get_state_proofs(&router, reads).await;
    let expected = [
        (k1, Felt::from(100u64)),
        (k2, Felt::from(200u64)),
        (k3, Felt::ZERO),
        (k1, Felt::from(1000u64)),
        (k2, Felt::ZERO),
        (k3, Felt::from(3000u64)),
        (k1, Felt::ZERO),
        (k2, Felt::from(20000u64)),
        (k3, Felt::ZERO),
    ];
    for (i, (proof, &(key, value))) in response.state_proofs.iter().zip(expected.iter()).enumerate() {
        let expected_membership = if value == Felt::ZERO {
            Membership::NonMember
        } else {
            Membership::Member
        };
        verify_read_proof_crypto(proof, key, value, &format!("det{}", i), Some(expected_membership));
    }
}
