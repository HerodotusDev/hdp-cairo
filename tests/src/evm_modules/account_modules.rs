use types::InjectedState;

use crate::test_utils::{load_compiled_class, run};

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_balance() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_account_get_balance.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_code_hash() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_account_get_code_hash.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_nonce() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_account_get_nonce.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_state_root() {
    dotenvy::dotenv().ok();
    if let Some(compiled_class) = load_compiled_class("tests_evm_account_get_state_root.compiled_contract_class.json") {
        run(compiled_class, InjectedState::default()).await;
    }
}
