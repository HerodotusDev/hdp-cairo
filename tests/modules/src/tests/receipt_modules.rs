use super::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_receipt_get_status() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_receipts_get_status.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_receipt_get_cumulative_gas_used() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_receipts_get_cumulative_gas_used.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
