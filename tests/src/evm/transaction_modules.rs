use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_nonce() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_nonce.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_modules_transaction_get_gas_price() {
//     run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/modules_transaction_get_gas_price.compiled_contract_class.json"
//     ))
//     .unwrap())
//     .await
// }

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_gas_limit() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_gas_limit.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_receiver() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_receiver.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_value() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_value.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_v() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_v.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_r() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_r.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_s() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_s.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_chain_id() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_chain_id.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_max_fee_per_gas() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_max_fee_per_gas.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_max_priority_fee_per_gas() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_max_priority_fee_per_gas.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_modules_transaction_get_max_fee_per_blob_gas() {
//     run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/modules_transaction_get_max_fee_per_blob_gas.
// compiled_contract_class.json"     ))
//     .unwrap())
//     .await
// }

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_tx_type() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_tx_type.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_sender() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_sender.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_transaction_get_hash() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_transaction_get_hash.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
