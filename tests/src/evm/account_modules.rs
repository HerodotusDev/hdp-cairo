use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_balance() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_account_get_balance.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_code_hash() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_account_get_code_hash.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_nonce() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_account_get_nonce.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_state_root() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_account_get_state_root.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
