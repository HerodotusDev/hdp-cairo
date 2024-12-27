use super::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_parent() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_parent.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_uncle() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_uncle.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_coinbase() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_coinbase.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_state_root() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_get_state_root.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_transaction_root() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_get_transaction_root.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_receipt_root() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_get_receipt_root.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_difficulty() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_get_difficulty.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_number() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_number.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_gas_limit() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_get_gas_limit.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_gas_used() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_gas_used.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_mix_hash() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_mix_hash.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_nonce() {
    run(serde_json::from_slice(include_bytes!("../../../../target/dev/modules_get_nonce.compiled_contract_class.json")).unwrap()).await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_get_base_fee_per_gas() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_get_base_fee_per_gas.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
