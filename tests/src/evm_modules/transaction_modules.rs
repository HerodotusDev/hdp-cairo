use types::InjectedState;

use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_nonce() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_nonce.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_gas_price() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_gas_price.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_gas_limit() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_gas_limit.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_receiver() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_receiver.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_value() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_value.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_v() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_v.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_r() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_r.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_s() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_s.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_chain_id() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_chain_id.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_tests_transaction_get_max_fee_per_gas() {
// dotenvy::dotenv().ok();//
// run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/tests_transaction_get_max_fee_per_gas.compiled_contract_class.json"
//     ))
//     .unwrap(), InjectedState::default())
//     .await
// }

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_tests_transaction_get_max_priority_fee_per_gas() {
// dotenvy::dotenv().ok();//
// run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/tests_transaction_get_max_priority_fee_per_gas.compiled_contract_class.json"
//     ))
//     .unwrap(), InjectedState::default())
//     .await
// }

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_tests_transaction_get_max_fee_per_blob_gas() {
// dotenvy::dotenv().ok();//
// run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/tests_transaction_get_max_fee_per_blob_gas.
// compiled_contract_class.json"     ))
//     .unwrap(), InjectedState::default())
//     .await
// }

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_tx_type_legacy() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_tx_type_legacy.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_tx_type_eip2930() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_tx_type_eip2930.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}


#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_tx_type_eip2559() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_tx_type_eip2559.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}


#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_tx_type_eip4844() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_tx_type_eip4844.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}


#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn transaction_get_tx_type_eip7702() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_tx_type_eip7702.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_sender() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_sender.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_tests_transaction_get_hash() {
    dotenvy::dotenv().ok();
    run(
        serde_json::from_slice(include_bytes!(
            "../../../target/dev/tests_transaction_get_hash.compiled_contract_class.json"
        ))
        .unwrap(),
        InjectedState::default(),
    )
    .await
}
