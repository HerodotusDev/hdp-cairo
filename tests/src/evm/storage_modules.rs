use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_evm_get_slot() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_evm_storage_get_slot.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
