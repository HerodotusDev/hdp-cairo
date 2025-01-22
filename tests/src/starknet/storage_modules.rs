use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_and_ethereum_get_storage() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_starknet_and_ethereum_get_storage.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_storage() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_starknet_get_storage.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
