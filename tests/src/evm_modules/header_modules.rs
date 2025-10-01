use types::InjectedState;

use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_parent() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_parent.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_uncle() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_uncle.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_coinbase() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_coinbase.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_state_root() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_state_root.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_transaction_root() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_transaction_root.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_receipt_root() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_receipt_root.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_difficulty() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_difficulty.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_number() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_number.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_gas_limit() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_gas_limit.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_gas_used() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_gas_used.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_mix_hash() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_mix_hash.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_nonce() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_nonce.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_base_fee_per_gas() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_header_get_base_fee_per_gas.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}
