cargo run --release --bin dry_run -- \
    -m target/dev/example_compliance_module.compiled_contract_class.json \
    --inputs examples/compliance/input.json \
    --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- \
    -m target/dev/example_compliance_module.compiled_contract_class.json \
    --inputs examples/compliance/input.json \
    --print_output