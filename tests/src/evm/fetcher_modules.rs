use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_evm_fetcher_many_keys_same_header() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_evm_fetcher_many_keys_same_header.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_evm_fetcher_many_keys_same_header_10x() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_evm_fetcher_many_keys_same_header_10x.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_evm_fetcher_many_txns_same_header() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_evm_fetcher_many_txns_same_header.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
