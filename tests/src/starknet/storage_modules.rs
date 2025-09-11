use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_starknet_get_storage() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_starknet_get_storage.compiled_contract_class.json"
        ))
        .unwrap(),
        None,
    )
    .await
}
