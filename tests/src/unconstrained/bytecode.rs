use types::InjectedState;

use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_account_get_bytecode_empty() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_account_get_bytecode_empty.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_account_get_bytecode_contract() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_evm_account_get_bytecode_contract.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}
