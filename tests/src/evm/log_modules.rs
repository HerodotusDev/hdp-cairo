use types::InjectedState;

use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_log_get_address() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_logs_get_address.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_log_get_topic0() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_logs_get_topic0.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_log_get_topic1() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_logs_get_topic1.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_log_get_topic2() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_logs_get_topic2.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_log_get_data() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_logs_get_data.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}
