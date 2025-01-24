use crate::test_utils::run;

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_modules_test_debug_print() {
    run(serde_json::from_slice(include_bytes!(
        "../../../target/dev/modules_test_debug_print.compiled_contract_class.json"
    ))
    .unwrap())
    .await
}
