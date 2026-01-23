use types::InjectedState;

use crate::test_utils::{load_compiled_class, run};

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_fetcher_many_keys_same_header() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_fetcher_many_keys_same_header.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_fetcher_many_keys_same_header_10x() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_fetcher_many_keys_same_header_10x.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_fetcher_many_txns_same_header() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_fetcher_many_txns_same_header.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}
