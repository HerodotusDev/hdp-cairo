#!/bin/bash

# Function to handle script termination and kill the state_server
cleanup() {
    kill $STATE_SERVER_PID
}

# Set a trap to run the cleanup function on script exit
# This ensures the state_server is stopped even if the script is interrupted
trap cleanup EXIT

cargo run --release --bin state_server &
STATE_SERVER_PID=$!

cargo run --release --bin dry_run -- \
    -m target/dev/example_all_features_combined_module.compiled_contract_class.json \
    --inputs examples/all_features_combined/input.json \
    --injected_state examples/all_features_combined/injected_state.json \
    --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- \
    -m target/dev/example_all_features_combined_module.compiled_contract_class.json \
    --inputs examples/all_features_combined/input.json \
    --injected_state examples/all_features_combined/injected_state.json \
    --print_output