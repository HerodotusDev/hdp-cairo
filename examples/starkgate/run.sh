cargo run --release --bin dry_run -- \
    -m target/dev/example_starkgate_module.compiled_contract_class.json \
    --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- \
    -m target/dev/example_starkgate_module.compiled_contract_class.json \
    --print_output