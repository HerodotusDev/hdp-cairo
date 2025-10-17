cargo run --release --bin dry_run -- \
    -m target/dev/example_multi_chain_access_module.compiled_contract_class.json \
    --print_output

# Proofs fetching stage
# Scenario 1 - let the indexer decide which MMRs to use
cargo run --bin fetcher

# Scenario 2 - you decide which MMRs to use
cargo run --bin fetcher -- --proofs-fetcher-config example_proof_fetcher_config.json

cargo run --release --bin sound_run -- \
    -m target/dev/example_multi_chain_access_module.compiled_contract_class.json \
    --print_output