#!/bin/bash

# Define the log file path
LOG_FILE="full_flow.log"

# Ensure the log file exists, otherwise create it
touch "$LOG_FILE"

# Export the log file path so it is available in subshells
export LOG_FILE

run_tests() {
    local input_file="$1"
    local temp_output=$(mktemp)

    # Attempt to run the compiled program and capture output
    local start_time=$(date +%s)
    cairo-run --program="build/compiled_cairo_files/hdp.json" --program_input="$input_file" --layout=starknet_with_keccak >> "$temp_output" 2>&1
    local status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successful test for $input_file: Duration ${duration} seconds"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed test for $input_file"
    fi

    cat "$temp_output" >> "$LOG_FILE"
    return $status
}

# Export the functions so they're available in subshells
export -f run_tests

# Ensure the Cairo file is compiled before running parallel tests
echo "Compiling HDP Cairo file..."
cairo-compile --cairo_path="packages/eth_essentials" "src/hdp.cairo" --output "build/compiled_cairo_files/hdp.json"

# Clone the repository if the directory doesn't exist
if [ ! -d "hdp-test" ]; then
    git clone https://github.com/HerodotusDev/hdp-test && cd hdp-test && git checkout syscalls && cd ..
fi

echo "Starting tests..."
# Use find to locate all input.json files in hdp-test/fixtures directory and run them in parallel
find ./hdp-test/fixtures -name "input.json" | parallel --halt soon,fail=1 run_tests {}

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
if [ $exit_status -ne 0 ]; then
    echo "Parallel execution exited with status: $exit_status. Some tests failed."
else
    echo "Parallel execution exited successfully. All tests passed."
fi

exit $exit_status
