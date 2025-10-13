cargo run --release --bin dry_run -- \
    -m target/dev/example_most_bridge_module.compiled_contract_class.json \
    --inputs examples/most_bridge/input.json \
    --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- \
    -m target/dev/example_most_bridge_module.compiled_contract_class.json \
    --inputs examples/most_bridge/input.json \
    --print_output