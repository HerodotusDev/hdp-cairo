use super::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_nonce() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_transaction_get_nonce.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
