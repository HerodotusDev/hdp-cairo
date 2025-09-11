use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_fetcher_many_keys_same_header() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_fetcher_many_keys_same_header.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_fetcher_many_keys_same_header_10x() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_fetcher_many_keys_same_header_10x.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_fetcher_many_txns_same_header() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_fetcher_many_txns_same_header.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}
