use types::InjectedState;

use crate::test_utils::run_compiled_class;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_status() {
    dotenvy::dotenv().ok();
    run_compiled_class("tests_receipts_get_status.compiled_contract_class.json", InjectedState::default()).await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_receipt_get_cumulative_gas_used() {
    dotenvy::dotenv().ok();
    run_compiled_class(
        "tests_receipts_get_and_tx_get.compiled_contract_class.json",
        InjectedState::default(),
    )
    .await;
}
