use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_poseidon_hash() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_hashers_poseidon.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_keccak_hash() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_hashers_keccak.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_pedersen_hash() {
    dotenvy::dotenv().ok();
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/tests_hashers_pedersen.compiled_contract_class.json"
    ))
    .unwrap(), None)
    .await
}
