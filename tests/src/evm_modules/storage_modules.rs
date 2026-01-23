use types::InjectedState;

use crate::test_utils::run_compiled_class;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_slot() {
    dotenvy::dotenv().ok();
    run_compiled_class("tests_evm_storage_get_slot.compiled_contract_class.json", InjectedState::default()).await;
}
