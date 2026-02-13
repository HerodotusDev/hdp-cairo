use types::InjectedState;

use crate::test_utils::run_compiled_class;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_poseidon_hash() {
    dotenvy::dotenv().ok();
    run_compiled_class("tests_hashers_poseidon.compiled_contract_class.json", InjectedState::default()).await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_keccak_hash() {
    dotenvy::dotenv().ok();
    run_compiled_class("tests_hashers_keccak.compiled_contract_class.json", InjectedState::default()).await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_pedersen_hash() {
    dotenvy::dotenv().ok();
    run_compiled_class("tests_hashers_pedersen.compiled_contract_class.json", InjectedState::default()).await;
}
