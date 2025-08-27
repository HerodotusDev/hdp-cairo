// use crate::test_utils::run;

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_tests_injected_state_read_write_single() {
//     dotenvy::dotenv().ok();
//     run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/tests_injected_state_read_write_single.compiled_contract_class.json"
//     ))
//     .unwrap())
//     .await
// }

// #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
// async fn test_tests_injected_state_read_write_multiple() {
//     dotenvy::dotenv().ok();
//     run(serde_json::from_slice(include_bytes!(
//         "../../../target/dev/tests_injected_state_read_write_multiple.compiled_contract_class.json"
//     ))
//     .unwrap())
//     .await
// }
