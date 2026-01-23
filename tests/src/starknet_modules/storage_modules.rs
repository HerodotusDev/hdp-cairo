use types::InjectedState;

use crate::test_utils::run_compiled_class;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_starknet_get_storage() {
    dotenvy::dotenv().ok();
    run_compiled_class("tests_starknet_get_storage.compiled_contract_class.json", InjectedState::default()).await;
}
