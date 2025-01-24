use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_evm_get_balance() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_evm_test_print.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}