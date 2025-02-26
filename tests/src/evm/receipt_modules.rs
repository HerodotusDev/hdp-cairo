use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_status() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_status.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_cumulative_gas_used() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_and_tx_get.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_address() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_address.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_topic0() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_topic0.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_topic1() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_topic1.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_topic2() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_topic2.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_data() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_receipts_get_data.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
