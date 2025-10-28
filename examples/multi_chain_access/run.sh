cargo run --release --bin dry_run -- \
    -m target/dev/example_multi_chain_access_module.compiled_contract_class.json \
    --print_output

cargo run --bin fetcher -- --mmr-hasher-config mmr_hasher_config.json

cargo run --release --bin sound_run -- \
    -m target/dev/example_multi_chain_access_module.compiled_contract_class.json \
    --print_output