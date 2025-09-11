use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_status() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_status.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_cumulative_gas_used() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_and_tx_get.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}
