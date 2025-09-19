use pathfinder_crypto::Felt;

use crate::helpers::{get_state_proofs, read_actions, read_from_trie, setup, write_to_trie};

#[tokio::test]
async fn isolation_root_stability_other_trie_unchanged() {
    let (router, _) = setup().await.unwrap();
    let (trie_a, trie_b) = (Felt::from(0xA_u64), Felt::from(0xB_u64));

    // Initial roots are zero (implicit)
    let root_a_0 = Felt::ZERO;
    let root_b_0 = Felt::ZERO;

    // Write to trie A
    let k1 = Felt::from(1u64);
    let v1 = Felt::from(100u64);
    let root_a_1 = write_to_trie(&router, trie_a, root_a_0, k1, v1).await.trie_root;

    assert_ne!(root_a_0, root_a_1, "Trie A root must change after write");
    // Trie B root should remain zero; reading from B yields zero
    assert_eq!(root_b_0, Felt::ZERO);
    let resp = get_state_proofs(&router, read_actions(trie_b, root_b_0, vec![k1])).await;
    assert_eq!(resp.state_proofs.len(), 1);
    // value must be zero in other trie
    match &resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, Felt::ZERO);
        }
        _ => {
            panic!("Expected read proof, got {:?}", resp.state_proofs[0]);
        }
    }
}

#[tokio::test]
async fn deletion_semantics_write_zero() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0xC_u64);
    let (k, v) = (Felt::from(1u64), Felt::from(100u64));

    let r1 = write_to_trie(&router, label, Felt::ZERO, k, v).await.trie_root;
    let r2 = write_to_trie(&router, label, r1, k, Felt::ZERO).await.trie_root;

    // Implementation-specific: we assert value reads as zero post-deletion.
    // Assert a root change occurred (if deletion persists a state change) or document otherwise.
    assert_ne!(r1, r2, "Deleting a key should change the root");
    // Assert that read returns zero.
    let resp = get_state_proofs(&router, read_actions(label, r2, vec![k])).await;
    match &resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, Felt::ZERO);
        }
        _ => {
            panic!("Expected read proof, got {:?}", resp.state_proofs[0]);
        }
    }
}

#[tokio::test]
async fn noop_write_same_value_keeps_root() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0xD_u64);
    let (k, v) = (Felt::from(2u64), Felt::from(200u64));

    let r1 = write_to_trie(&router, label, Felt::ZERO, k, v).await.trie_root;
    let r2 = write_to_trie(&router, label, r1, k, v).await.trie_root;

    // Define desired invariant: same (key,value) should not change root.
    assert_eq!(r1, r2, "No-op write should keep root unchanged");
}

#[tokio::test]
async fn order_independence_two_keys_on_empty_trie() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0xE_u64);
    let (k1, v1) = (Felt::from(10u64), Felt::from(1000u64));
    let (k2, v2) = (Felt::from(11u64), Felt::from(2000u64));

    let r_a1 = write_to_trie(&router, label, Felt::ZERO, k1, v1).await.trie_root;
    let r_a2 = write_to_trie(&router, label, r_a1, k2, v2).await.trie_root;

    // Fresh trie for reversed order
    let (router2, _) = setup().await.unwrap();
    let r_b1 = write_to_trie(&router2, label, Felt::ZERO, k2, v2).await.trie_root;
    let r_b2 = write_to_trie(&router2, label, r_b1, k1, v1).await.trie_root;

    assert_eq!(r_a2, r_b2, "Order of inserting two distinct keys should not affect final root");
}

#[tokio::test]
async fn edge_inputs_zero_and_max() {
    let (router, _) = setup().await.unwrap();
    let label_zero = Felt::ZERO;
    let key_zero = Felt::ZERO;
    let val_zero = Felt::ZERO;
    let r0 = write_to_trie(&router, label_zero, Felt::ZERO, key_zero, val_zero).await.trie_root;
    let resp0 = get_state_proofs(&router, read_actions(label_zero, r0, vec![key_zero])).await;
    if let types::proofs::injected_state::StateProof::Read(p) = &resp0.state_proofs[0] {
        assert_eq!(p.leaf.data.value, Felt::ZERO);
    }

    // Max felt constrained by path length (251 bits). Use a 31-byte value with top bit clear.
    let max = Felt::from_hex_str("0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff").unwrap();
    let label = Felt::from(0xF_u64);
    let r1 = write_to_trie(&router, label, Felt::ZERO, max, max).await.trie_root;
    let resp1 = read_from_trie(&router, label, r1, max).await;
    assert_eq!(resp1.value, Some(max));
}

#[tokio::test]
async fn empty_trie_operations() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x10_u64);

    // Test reading from empty trie
    let empty_root = Felt::ZERO;
    let test_key = Felt::from(0x123_u64);

    let resp = get_state_proofs(&router, read_actions(label, empty_root, vec![test_key])).await;
    assert_eq!(resp.state_proofs.len(), 1);

    match &resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, Felt::ZERO, "Empty trie should return zero for any key");
            assert_eq!(p.leaf.key, test_key, "Should return the requested key");
        }
        _ => {
            panic!("Expected read proof, got {:?}", resp.state_proofs[0]);
        }
    }

    // Test writing to empty trie and then reading back
    let value = Felt::from(0x456_u64);
    let new_root = write_to_trie(&router, label, empty_root, test_key, value).await.trie_root;
    assert_ne!(new_root, empty_root, "Writing to empty trie should change root");

    let read_resp = get_state_proofs(&router, read_actions(label, new_root, vec![test_key])).await;
    match &read_resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value, "Should read back the written value");
        }
        _ => {
            panic!("Expected read proof, got {:?}", read_resp.state_proofs[0]);
        }
    }
}

#[tokio::test]
async fn boundary_value_testing() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x11_u64);

    // Test with minimum non-zero values
    let min_key = Felt::from(1u64);
    let min_value = Felt::from(1u64);

    let root1 = write_to_trie(&router, label, Felt::ZERO, min_key, min_value).await.trie_root;
    assert_ne!(root1, Felt::ZERO, "Writing minimum values should change root");

    // Test with large values (but not maximum)
    let large_key = Felt::from_hex_str("0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff").unwrap();
    let large_value = Felt::from_hex_str("0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe").unwrap();

    let root2 = write_to_trie(&router, label, root1, large_key, large_value).await.trie_root;
    assert_ne!(root2, root1, "Writing large values should change root");

    // Verify both values can be read back
    let read_resp = get_state_proofs(&router, read_actions(label, root2, vec![min_key, large_key])).await;
    assert_eq!(read_resp.state_proofs.len(), 2);

    match &read_resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, min_value, "Should read back minimum value");
        }
        _ => panic!("Expected read proof for min_key"),
    }

    match &read_resp.state_proofs[1] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, large_value, "Should read back large value");
        }
        _ => panic!("Expected read proof for large_key"),
    }
}

#[tokio::test]
async fn single_key_trie_operations() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x12_u64);
    let key = Felt::from(0x123_u64);
    let value = Felt::from(0x456_u64);

    // Test single key write
    let root = write_to_trie(&router, label, Felt::ZERO, key, value).await.trie_root;
    assert_ne!(root, Felt::ZERO, "Single key write should change root");

    // Test reading the single key
    let read_resp = get_state_proofs(&router, read_actions(label, root, vec![key])).await;
    match &read_resp.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value, "Should read back the single key value");
        }
        _ => panic!("Expected read proof for single key"),
    }

    // Test reading non-existent key from single-key trie
    let non_existent_key = Felt::from(0x789_u64);
    let read_non_existent = get_state_proofs(&router, read_actions(label, root, vec![non_existent_key])).await;
    match &read_non_existent.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, Felt::ZERO, "Non-existent key should return zero");
        }
        _ => panic!("Expected read proof for non-existent key"),
    }
}

#[tokio::test]
async fn trie_label_collision_handling() {
    let (router, _) = setup().await.unwrap();

    // Test that different trie labels are truly isolated
    let label_a = Felt::from(0x13_u64);
    let label_b = Felt::from(0x14_u64);
    let shared_key = Felt::from(0x123_u64);
    let value_a = Felt::from(0x456_u64);
    let value_b = Felt::from(0x789_u64);

    // Write same key to different tries
    let root_a = write_to_trie(&router, label_a, Felt::ZERO, shared_key, value_a).await.trie_root;
    let root_b = write_to_trie(&router, label_b, Felt::ZERO, shared_key, value_b).await.trie_root;

    // Verify they have different roots
    assert_ne!(root_a, root_b, "Different trie labels should have different roots");

    // Verify each trie returns its own value
    let resp_a = get_state_proofs(&router, read_actions(label_a, root_a, vec![shared_key])).await;
    let resp_b = get_state_proofs(&router, read_actions(label_b, root_b, vec![shared_key])).await;

    match &resp_a.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value_a, "Trie A should return value_a");
        }
        _ => panic!("Expected read proof from trie A"),
    }

    match &resp_b.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value_b, "Trie B should return value_b");
        }
        _ => panic!("Expected read proof from trie B"),
    }
}

#[tokio::test]
async fn key_value_permutation_testing() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x15_u64);

    // Test various key-value combinations (using only safe, non-zero values)
    let test_cases = vec![
        (Felt::from(1u64), Felt::from(100u64)),       // Simple key-value pair
        (Felt::from(2u64), Felt::from(200u64)),       // Another simple pair
        (Felt::from(0x123u64), Felt::from(0x456u64)), // Hex-like values
    ];

    let mut current_root = Felt::ZERO;
    let mut expected_values = Vec::new();

    for (key, value) in test_cases.iter() {
        let new_root = write_to_trie(&router, label, current_root, *key, *value).await.trie_root;
        // Note: Some writes might not change root (e.g., zero key-value to empty trie)
        // We'll track the root regardless
        current_root = new_root;
        expected_values.push((*key, *value));
    }

    // Verify all values can be read back
    let keys: Vec<Felt> = expected_values.iter().map(|(k, _)| *k).collect();
    let read_resp = get_state_proofs(&router, read_actions(label, current_root, keys)).await;

    assert_eq!(read_resp.state_proofs.len(), expected_values.len());

    for (i, (expected_key, expected_value)) in expected_values.iter().enumerate() {
        match &read_resp.state_proofs[i] {
            types::proofs::injected_state::StateProof::Read(p) => {
                assert_eq!(p.leaf.key, *expected_key, "Key should match at index {}", i);
                assert_eq!(p.leaf.data.value, *expected_value, "Value should match at index {}", i);
            }
            _ => panic!("Expected read proof at index {}", i),
        }
    }
}

#[tokio::test]
async fn trie_state_transition_consistency() {
    let (router, _) = setup().await.unwrap();
    let label = Felt::from(0x16_u64);

    // Test that trie state transitions are consistent
    let key = Felt::from(0x123_u64);
    let value1 = Felt::from(0x456_u64);
    let value2 = Felt::from(0x789_u64);
    let value3 = Felt::from(0xABC_u64);

    // Write sequence: value1 -> value2 -> value3
    let root1 = write_to_trie(&router, label, Felt::ZERO, key, value1).await.trie_root;
    let root2 = write_to_trie(&router, label, root1, key, value2).await.trie_root;
    let root3 = write_to_trie(&router, label, root2, key, value3).await.trie_root;

    // Verify roots change at each step
    assert_ne!(Felt::ZERO, root1, "First write should change root");
    assert_ne!(root1, root2, "Second write should change root");
    assert_ne!(root2, root3, "Third write should change root");

    // Verify each state can be read correctly
    let read1 = get_state_proofs(&router, read_actions(label, root1, vec![key])).await;
    let read2 = get_state_proofs(&router, read_actions(label, root2, vec![key])).await;
    let read3 = get_state_proofs(&router, read_actions(label, root3, vec![key])).await;

    // Check state 1
    match &read1.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value1, "State 1 should have value1");
        }
        _ => panic!("Expected read proof for state 1"),
    }

    // Check state 2
    match &read2.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value2, "State 2 should have value2");
        }
        _ => panic!("Expected read proof for state 2"),
    }

    // Check state 3
    match &read3.state_proofs[0] {
        types::proofs::injected_state::StateProof::Read(p) => {
            assert_eq!(p.leaf.data.value, value3, "State 3 should have value3");
        }
        _ => panic!("Expected read proof for state 3"),
    }
}
