use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use test_context::{test_context, AsyncTestContext};

use crate::{test_state_server::TestStateServer, test_utils::run};

pub struct StateServerCtx(pub TestStateServer);

impl AsyncTestContext for StateServerCtx {
    async fn setup() -> Self {
        let _ = dotenvy::dotenv();

        let mut socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
        let server = TestStateServer::start(socket).await.unwrap();
        socket.set_port(server.port);

        // Set the environment variable so the syscall handler can find the server
        // The syscall handler expects INJECTED_STATE_BASE_URL
        std::env::set_var("INJECTED_STATE_BASE_URL", format!("http://{}", socket));

        StateServerCtx(server)
    }

    async fn teardown(self) -> () {
        self.0.stop().await.unwrap();
    }
}

// Write tests
#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_boundary_value_testing(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_boundary_value_testing.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/boundary_value_testing_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_cross_trie_collision_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_cross_trie_collision_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/cross_trie_collision_test_injected_state.json")).unwrap(),
    )
    .await
}

// Invariant tests
#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_edge_inputs_max(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_edge_inputs_max.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/edge_inputs_max_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_empty_trie_operations(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_empty_trie_operations.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/empty_trie_operations_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_isolation_root_stability(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_isolation_root_stability.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/isolation_root_stability_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_key_value_permutation_testing(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_key_value_permutation_testing.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/key_value_permutation_testing_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_multi_trie_deterministic_reads(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_multi_trie_deterministic_reads.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/multi_trie_deterministic_reads_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_multiple_key_overrides(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_multiple_key_overrides.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/multiple_key_overrides_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_multiple_tries_proofs_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_multiple_tries_proofs_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/multiple_tries_proofs_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_non_sequential_proof_verification(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_non_sequential_proof_verification.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/non_sequential_proof_verification_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_noop_write_same_value(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_noop_write_same_value.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/noop_write_same_value_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_order_independence_two_keys(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_order_independence_two_keys.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/order_independence_two_keys_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_override_existing_key(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_override_existing_key.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/override_existing_key_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_random_reads_across_multiple_tries(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_random_reads_across_multiple_tries.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/random_reads_across_multiple_tries_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_duplicate_keys(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_duplicate_keys.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_duplicate_keys_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_edge_cases(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_edge_cases.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_edge_cases_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_empty_key_list(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_empty_key_list.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_empty_key_list_injected_state.json")).unwrap(),
    )
    .await
}

// Read tests
#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_from_trie_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_from_trie_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_from_trie_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_large_key_set(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_large_key_set.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_large_key_set_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_mixed_existing_non_existing(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_mixed_existing_non_existing.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_mixed_existing_non_existing_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_non_existent_key(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_non_existent_key.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_non_existent_key_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_sequential_key_patterns(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_sequential_key_patterns.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_sequential_key_patterns_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_read_sparse_key_distribution(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_read_sparse_key_distribution.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/read_sparse_key_distribution_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_found_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_found_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/root_found_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_found_wrong_label_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_found_wrong_label_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/root_found_wrong_label_test_injected_state.json")).unwrap(),
    )
    .await
}

// Root to node idx tests
#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_is_zero_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_is_zero_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/root_is_zero_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_root_not_found_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_root_not_found_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/root_not_found_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_single_key_trie_operations(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_single_key_trie_operations.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/single_key_trie_operations_injected_state.json")).unwrap(),
    )
    .await
}

// Proof tests
#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_single_trie_proofs_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_single_trie_proofs_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/single_trie_proofs_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_trie_label_collision_handling(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_trie_label_collision_handling.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/trie_label_collision_handling_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_trie_state_transition_consistency(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_trie_state_transition_consistency.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/trie_state_transition_consistency_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_verify_proofs_multiple_tries_test(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_verify_proofs_multiple_tries_test.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/verify_proofs_multiple_tries_test_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_alternating_patterns(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_alternating_patterns.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_alternating_patterns_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_circular_value_pattern(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_circular_value_pattern.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_circular_value_pattern_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_concurrent_key_access(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_concurrent_key_access.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_concurrent_key_access_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_edge_cases(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_edge_cases.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_edge_cases_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_large_number_of_keys(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_large_number_of_keys.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_large_number_of_keys_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_same_value_multiple_times(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_same_value_multiple_times.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_same_value_multiple_times_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_sequential_overwrites(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_sequential_overwrites.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_sequential_overwrites_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_to_existing_trie(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_to_existing_trie.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_to_existing_trie_injected_state.json")).unwrap(),
    )
    .await
}

#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_write_to_new_trie(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_write_to_new_trie.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/write_to_new_trie_injected_state.json")).unwrap(),
    )
    .await
}

// Special tests
#[test_context(StateServerCtx)]
#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_injected_state_zero_labeled_trie(_: &mut StateServerCtx) {
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_zero_labeled_trie.compiled_contract_class.json"
        ))
        .unwrap(),
        serde_json::from_slice(include_bytes!("modules/zero_labeled_trie_injected_state.json")).unwrap(),
    )
    .await
}
