use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_block_number() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_block_number.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_state_root() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_state_root.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_sequencer_address() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_sequencer_address.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_block_timestamp() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_block_timestamp.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_transaction_commitment() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_transaction_commitment.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_event_commitment() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_event_commitment.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_parent_block_hash() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_parent_block_hash.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_state_diff_commitment() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_state_diff_commitment.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_l1_gas_price_in_wei() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_l1_gas_price_in_wei.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_l1_gas_price_in_fri() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_l1_gas_price_in_fri.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_l1_data_gas_price_in_wei() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_l1_data_gas_price_in_wei.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_l1_data_gas_price_in_fri() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_l1_data_gas_price_in_fri.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_receipts_commitment() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_receipts_commitment.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_transaction_count() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_transaction_count.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_event_count() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_event_count.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_state_diff_length() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_state_diff_length.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_l1_data_mode() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_l1_data_mode.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_starknet_get_protocol_version() {
    run(serde_json::from_slice(include_bytes!(
        "../../../../target/dev/modules_starknet_get_protocol_version.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
