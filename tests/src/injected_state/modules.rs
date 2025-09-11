use crate::test_utils::run;

// Write tests
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_boundary_value_testing() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_boundary_value_testing.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_cross_trie_collision_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_cross_trie_collision_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

// Invariant tests
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_edge_inputs_max() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_edge_inputs_max.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_empty_trie_operations() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_empty_trie_operations.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_isolation_root_stability() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_isolation_root_stability.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_key_value_permutation_testing() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_key_value_permutation_testing.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_multi_trie_deterministic_reads() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_multi_trie_deterministic_reads.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_multiple_key_overrides() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_multiple_key_overrides.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_multiple_tries_proofs_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_multiple_tries_proofs_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_non_sequential_proof_verification() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_non_sequential_proof_verification.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_noop_write_same_value() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_noop_write_same_value.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_order_independence_two_keys() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_order_independence_two_keys.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_override_existing_key() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_override_existing_key.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_random_reads_across_multiple_tries() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_random_reads_across_multiple_tries.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_duplicate_keys() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_duplicate_keys.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_edge_cases() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_edge_cases.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_empty_key_list() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_empty_key_list.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

// Read tests
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_from_trie_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_from_trie_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_large_key_set() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_large_key_set.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_mixed_existing_non_existing() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_mixed_existing_non_existing.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_non_existent_key() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_non_existent_key.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_sequential_key_patterns() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_sequential_key_patterns.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_sparse_key_distribution() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_sparse_key_distribution.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_found_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_found_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_found_wrong_label_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_found_wrong_label_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

// Root to node idx tests
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_is_zero_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_is_zero_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_not_found_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_not_found_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_single_key_trie_operations() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_single_key_trie_operations.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

// Proof tests
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_single_trie_proofs_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_single_trie_proofs_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_trie_label_collision_handling() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_trie_label_collision_handling.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_trie_state_transition_consistency() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_trie_state_transition_consistency.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_verify_proofs_multiple_tries_test() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_verify_proofs_multiple_tries_test.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_alternating_patterns() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_alternating_patterns.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_circular_value_pattern() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_circular_value_pattern.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_concurrent_key_access() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_concurrent_key_access.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_edge_cases() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_edge_cases.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_large_number_of_keys() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_large_number_of_keys.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_same_value_multiple_times() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_same_value_multiple_times.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_sequential_overwrites() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_sequential_overwrites.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_to_existing_trie() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_to_existing_trie.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_to_new_trie() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_to_new_trie.compiled_contract_class.json"
        ))
        .unwrap(),
        Some("injected_state.json"),
    )
    .await
}
