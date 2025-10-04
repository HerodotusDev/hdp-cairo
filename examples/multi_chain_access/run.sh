cargo run --release --bin dry_run -- \
    -m target/dev/example_simple_test_evm_storage_get_slot.compiled_contract_class.json \
    --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- \
    -m target/dev/example_simple_test_evm_storage_get_slot.compiled_contract_class.json \
    --print_output