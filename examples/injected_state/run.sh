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
    -m target/dev/example_injected_state_module.compiled_contract_class.json \
    --injected_state examples/injected_state/injected_state.json \
    --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- \
    -m target/dev/example_injected_state_module.compiled_contract_class.json \
    --injected_state examples/injected_state/injected_state.json \
    --print_output