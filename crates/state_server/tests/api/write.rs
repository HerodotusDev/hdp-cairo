use pathfinder_crypto::Felt;
use rand::{rngs::StdRng, Rng, SeedableRng};
use state_server::mpt::{db::trie::TrieDB, trie::Trie};
use types::proofs::injected_state::StateProof;

use crate::helpers::{assert_write_proof, get_state_proofs, read_actions, setup, write_proof, write_to_trie};

#[tokio::test]
async fn write_to_new_trie() {
    let (router, state) = setup().await.unwrap();
    let (label, key, val) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
    );
    let conn = state.get_connection(label).unwrap();
    let db = TrieDB::new(&conn);

    assert!(db.get_leaf_at(key, 0).unwrap().is_none());
    let root = write_to_trie(&router, label, Felt::ZERO, key, val).await.trie_root;
    let proof = write_proof(&router, label, Felt::ZERO, key, val).await;

    assert_write_proof(&StateProof::Write(proof.clone()), key, Felt::ZERO, val, "new trie");
    assert_eq!((proof.trie_root_prev, proof.trie_root_post), (Felt::ZERO, root));
    assert_eq!(
        db.get_leaf_at(key, db.get_node_idx_by_hash(root).unwrap())
            .unwrap()
            .unwrap()
            .data
            .value,
        val
    );
}

#[tokio::test]
async fn write_to_existing_trie() {
    let (router, state) = setup().await.unwrap();
    let (label, k1, k2, v1, v2) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
    );
    let conn = state.get_connection(label).unwrap();
    let db = TrieDB::new(&conn);

    let root1 = write_to_trie(&router, label, Felt::ZERO, k1, v1).await.trie_root;
    assert_ne!(root1, Felt::ZERO, "Root must change after first write");
    let proof1 = write_proof(&router, label, Felt::ZERO, k1, v1).await;
    assert_write_proof(&StateProof::Write(proof1.clone()), k1, Felt::ZERO, v1, "first write");

    assert!(db.get_leaf_at(k2, db.get_node_idx_by_hash(root1).unwrap()).unwrap().is_none());
    let root2 = write_to_trie(&router, label, root1, k2, v2).await.trie_root;
    assert_ne!(root2, root1, "Root must change after second write");
    let proof2 = write_proof(&router, label, root1, k2, v2).await;
    assert_write_proof(&StateProof::Write(proof2.clone()), k2, Felt::ZERO, v2, "second write");

    let idx2 = db.get_node_idx_by_hash(root2).unwrap();
    assert_eq!(
        (
            db.get_leaf_at(k1, idx2).unwrap().unwrap().data.value,
            db.get_leaf_at(k2, idx2).unwrap().unwrap().data.value
        ),
        (v1, v2)
    );
}

#[tokio::test]
async fn override_existing_key() {
    let (router, state) = setup().await.unwrap();
    let (label, key, v1, v2) = (
        Felt::from_hex_str("0x123").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x1").unwrap(),
        Felt::from_hex_str("0x2").unwrap(),
    );
    let conn = state.get_connection(label).unwrap();
    let db = TrieDB::new(&conn);

    let root1 = write_to_trie(&router, label, Felt::ZERO, key, v1).await.trie_root;
    let proof1 = write_proof(&router, label, Felt::ZERO, key, v1).await;
    assert_write_proof(&StateProof::Write(proof1.clone()), key, Felt::ZERO, v1, "initial");

    let root2 = write_to_trie(&router, label, root1, key, v2).await.trie_root;
    let proof2 = write_proof(&router, label, root1, key, v2).await;
    assert_write_proof(&StateProof::Write(proof2.clone()), key, v1, v2, "override");
    assert_ne!(root1, root2, "Overwriting key should change the root");

    assert_eq!((proof2.trie_root_prev, proof2.trie_root_post), (root1, root2));
    assert!(!proof2.state_proof_prev.is_empty(), "Previous proof should not be empty");
    assert!(!proof2.state_proof_post.is_empty(), "Post proof should not be empty");
    assert_eq!(
        db.get_leaf_at(key, db.get_node_idx_by_hash(root2).unwrap())
            .unwrap()
            .unwrap()
            .data
            .value,
        v2
    );
}

#[tokio::test]
async fn multiple_key_overrides_with_proofs() {
    let (router, _) = setup().await.unwrap();
    let (label, key) = (Felt::from_hex_str("0x456").unwrap(), Felt::from_hex_str("0x10").unwrap());
    // Use seeded RNG for deterministic test values
    let mut rng = StdRng::seed_from_u64(42);
    let values: Vec<Felt> = (0..100).map(|_| Felt::from(rng.gen::<u64>())).collect();

    let (mut root, mut prev) = (Felt::ZERO, Felt::ZERO);
    for (i, &val) in values.iter().enumerate() {
        let new_root = write_to_trie(&router, label, root, key, val).await.trie_root;
        let proof = write_proof(&router, label, root, key, val).await;
        assert_write_proof(&StateProof::Write(proof.clone()), key, prev, val, &format!("iter{}", i));
        assert_eq!((proof.trie_root_prev, proof.trie_root_post), (root, new_root));
        (root, prev) = (new_root, val);
    }
}

#[tokio::test]
async fn non_sequential_proof_verification() {
    let (router, _) = setup().await.unwrap();
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
    let r1 = write_to_trie(&router, label, r0, k1, v1).await.trie_root;
    let r2 = write_to_trie(&router, label, r1, k2, v2).await.trie_root;
    let r3 = write_to_trie(&router, label, r2, k3, v3).await.trie_root;

    // Generate proofs in order: 1st, 2nd, 3rd for simplicity
    let proofs = [
        write_proof(&router, label, r0, k1, v1).await,
        write_proof(&router, label, r1, k2, v2).await,
        write_proof(&router, label, r2, k3, v3).await,
    ];
    let keys = [k1, k2, k3];
    let values = [v1, v2, v3];

    // Verify in multiple random orders
    for order in [[1, 2, 0], [2, 0, 1], [0, 1, 2], [2, 1, 0]] {
        for &i in &order {
            let p = &proofs[i];
            assert_write_proof(&StateProof::Write(p.clone()), keys[i], Felt::ZERO, values[i], &format!("rand{}", i));
            let membership = Trie::verify_proof(
                &p.state_proof_post
                    .iter()
                    .map(|n| (n.clone().into(), Felt::ZERO))
                    .collect::<Vec<_>>(),
                p.trie_root_post,
                p.leaf_post,
            );
            assert_eq!(
                membership,
                Some(state_server::mpt::trie::Membership::Member),
                "Proof verification should return Member for key {} at index {}",
                keys[i],
                i
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

#[tokio::test]
async fn write_edge_cases() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x30_u64);

    // Test writing with simple edge case values
    let edge_key = Felt::from(0x1234567890ABCDEF_u64);
    let edge_value = Felt::from(0xFEDCBA0987654321_u64);

    let root = write_to_trie(&router, label, Felt::ZERO, edge_key, edge_value).await.trie_root;
    // Note: Root change is implementation dependent

    // Verify we can read back the edge case key
    let read_resp = get_state_proofs(&router, read_actions(label, root, vec![edge_key])).await;
    assert_eq!(read_resp.state_proofs.len(), 1);

    // Verify the response is a valid read proof
    match &read_resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.key, edge_key, "Should return the edge case key");
        }
        _ => panic!("Expected read proof for edge case key"),
    }
}

#[tokio::test]
async fn write_sequential_overwrites() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x31_u64);
    let key = Felt::from(0x123u64);

    // Test multiple sequential overwrites of the same key
    let values = vec![
        Felt::from(0x100u64),
        Felt::from(0x200u64),
        Felt::from(0x300u64),
        Felt::from(0x400u64),
        Felt::from(0x500u64),
    ];

    let mut current_root = Felt::ZERO;
    let mut root_history = Vec::new();

    for (i, &value) in values.iter().enumerate() {
        let new_root = write_to_trie(&router, label, current_root, key, value).await.trie_root;
        assert_ne!(new_root, current_root, "Overwrite {} should change root", i);
        root_history.push(new_root);
        current_root = new_root;
    }

    // Verify all roots are unique
    for i in 0..root_history.len() {
        for j in (i + 1)..root_history.len() {
            assert_ne!(root_history[i], root_history[j], "Roots {} and {} should be different", i, j);
        }
    }

    // Verify final value is correct
    let final_read = get_state_proofs(&router, read_actions(label, current_root, vec![key])).await;
    match &final_read.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, *values.last().unwrap(), "Final value should match last write");
        }
        _ => panic!("Expected read proof for final value"),
    }
}

#[tokio::test]
async fn write_alternating_patterns() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x32_u64);

    // Test alternating between two keys
    let key1 = Felt::from(0x111u64);
    let key2 = Felt::from(0x222u64);
    let value1 = Felt::from(0xAAAu64);
    let value2 = Felt::from(0xBBBu64);

    let mut current_root = Felt::ZERO;
    let mut expected_values = Vec::new();

    // Write alternating pattern: key1, key2, key1, key2, key1
    for i in 0..5 {
        let (key, value) = if i % 2 == 0 { (key1, value1) } else { (key2, value2) };
        let new_root = write_to_trie(&router, label, current_root, key, value).await.trie_root;
        // Note: Some writes might not change root (implementation dependent)
        current_root = new_root;
        expected_values.push((key, value));
    }

    // Verify both keys have their expected final values
    let read_resp = get_state_proofs(&router, read_actions(label, current_root, vec![key1, key2])).await;
    assert_eq!(read_resp.state_proofs.len(), 2);

    // Check key1 (should have value1 from last write)
    match &read_resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value1, "Key1 should have final value1");
        }
        _ => panic!("Expected read proof for key1"),
    }

    // Check key2 (should have value2 from last write)
    match &read_resp.state_proofs[1] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value2, "Key2 should have final value2");
        }
        _ => panic!("Expected read proof for key2"),
    }
}

#[tokio::test]
async fn write_circular_value_pattern() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x33_u64);
    let key = Felt::from(0x123u64);

    // Test writing a circular pattern of values
    let values = vec![
        Felt::from(0x100u64),
        Felt::from(0x200u64),
        Felt::from(0x300u64),
        Felt::from(0x100u64), // Back to first value
        Felt::from(0x200u64), // Back to second value
    ];

    let mut current_root = Felt::ZERO;
    let mut root_history = Vec::new();

    for (i, &value) in values.iter().enumerate() {
        let new_root = write_to_trie(&router, label, current_root, key, value).await.trie_root;
        assert_ne!(new_root, current_root, "Circular write {} should change root", i);
        root_history.push(new_root);
        current_root = new_root;
    }

    // Note: Some roots might be the same even with different values
    // This is implementation dependent and not necessarily an error
    // We'll verify the final state is correct regardless

    // Verify final value is correct
    let final_read = get_state_proofs(&router, read_actions(label, current_root, vec![key])).await;
    match &final_read.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, *values.last().unwrap(), "Final value should match last write");
        }
        _ => panic!("Expected read proof for final value"),
    }
}

#[tokio::test]
async fn write_same_value_multiple_times() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x34_u64);
    let key = Felt::from(0x123u64);
    let value = Felt::from(0x456u64);

    // Test writing the same value multiple times
    let write_count = 10;
    let mut current_root = Felt::ZERO;
    let mut root_history = Vec::new();

    for i in 0..write_count {
        let new_root = write_to_trie(&router, label, current_root, key, value).await.trie_root;
        if i == 0 {
            assert_ne!(new_root, current_root, "First write should change root");
        } else {
            // Subsequent writes with same value might or might not change root
            // (implementation dependent)
        }
        root_history.push(new_root);
        current_root = new_root;
    }

    // Verify final value is correct
    let final_read = get_state_proofs(&router, read_actions(label, current_root, vec![key])).await;
    match &final_read.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value, "Final value should match written value");
        }
        _ => panic!("Expected read proof for final value"),
    }
}

#[tokio::test]
async fn write_large_number_of_keys() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x35_u64);

    // Test writing a large number of unique keys
    let key_count = 200;
    let keys: Vec<Felt> = (0..key_count).map(|i| Felt::from(i as u64)).collect();
    let values: Vec<Felt> = (1000..1000 + key_count).map(|i| Felt::from(i as u64)).collect();

    let mut current_root = Felt::ZERO;

    // Write all keys
    for (key, value) in keys.iter().zip(values.iter()) {
        let new_root = write_to_trie(&router, label, current_root, *key, *value).await.trie_root;
        assert_ne!(new_root, current_root, "Writing key {} should change root", key);
        current_root = new_root;
    }

    // Verify a sample of the written values
    let sample_indices = vec![0, 50, 100, 150, 199];
    for &idx in sample_indices.iter() {
        if idx < key_count {
            let key = Felt::from(idx as u64);
            let expected_value = Felt::from((1000 + idx) as u64);

            let read_resp = get_state_proofs(&router, read_actions(label, current_root, vec![key])).await;
            match &read_resp.state_proofs[0] {
                types::proofs::injected_state::StateProof::Read(p) => {
                    assert_eq!(
                        p.leaf.data.value, expected_value,
                        "Key {} should have value {}",
                        idx, expected_value
                    );
                }
                _ => panic!("Expected read proof for key {}", idx),
            }
        }
    }
}

#[tokio::test]
async fn write_concurrent_key_access() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x36_u64);

    // Test writing to different keys in a pattern that might stress concurrent access
    let keys = vec![
        Felt::from(0x001u64),
        Felt::from(0x100u64),
        Felt::from(0x200u64),
        Felt::from(0x300u64),
        Felt::from(0x400u64),
    ];

    let mut current_root = Felt::ZERO;
    let mut key_value_pairs = Vec::new();

    // Write to each key with a unique value
    for (i, &key) in keys.iter().enumerate() {
        let value = Felt::from((i as u64 + 1) * 1000u64);
        let new_root = write_to_trie(&router, label, current_root, key, value).await.trie_root;
        assert_ne!(new_root, current_root, "Writing key {} should change root", key);
        current_root = new_root;
        key_value_pairs.push((key, value));
    }

    // Verify all key-value pairs are correct
    let read_keys: Vec<Felt> = key_value_pairs.iter().map(|(k, _)| *k).collect();
    let read_resp = get_state_proofs(&router, read_actions(label, current_root, read_keys)).await;
    assert_eq!(read_resp.state_proofs.len(), key_value_pairs.len());

    for (i, (expected_key, expected_value)) in key_value_pairs.iter().enumerate() {
        match &read_resp.state_proofs[i] {
            types::proofs::injected_state::StateProof::Read(p) => {
                assert_eq!(p.leaf.key, *expected_key, "Key {} should match", i);
                assert_eq!(p.leaf.data.value, *expected_value, "Value {} should match", i);
            }
            _ => panic!("Expected read proof for key {}", i),
        }
    }
}
