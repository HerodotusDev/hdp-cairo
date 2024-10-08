#!/bin/bash

# Activate virtual environment
source venv/bin/activate

# Get the Cairo file from the command line argument
cairo_file="$1"
filename=$(basename "$cairo_file" .cairo)

# Define the log file path incorporating the filename
LOG_FILE="test_results_${filename}.log"

# Ensure the log file exists, otherwise create it
touch "$LOG_FILE"

# Export the log file path so it is available in subshells
export LOG_FILE

# Function to run tests on a given Cairo file
run_tests() {
    local cairo_file="$1"
    local filename=$(basename "$cairo_file" .cairo)
    local temp_output=$(mktemp)

    # Attempt to run the compiled program and capture output
    local start_time=$(date +%s)
    cairo-run --program="build/compiled_cairo_files/$filename.json" --layout=starknet_with_keccak >> "$temp_output" 2>&1
    local status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Handle output based on success or failure
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Test Successful: Duration ${duration} seconds"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Test Failed: Duration ${duration} seconds"
        cat "$temp_output"  # Output the error to the console
    fi

    cat "$temp_output" >> "$LOG_FILE"
    rm -f "$temp_output" # Clean up temporary file
    return $status
}

# Ensure the Cairo file is compiled before running parallel tests
echo "Compiling the Cairo file..."
cairo-compile --cairo_path="packages/eth_essentials" "$cairo_file" --output "build/compiled_cairo_files/$filename.json"

# Export the function so it's accessible to subshells spawned by parallel
export -f run_tests

# Run the same test file repeatedly, maintaining N parallel instances
seq inf | parallel --halt soon,fail=1 run_tests $cairo_file

# Capture and return the exit status of parallel
exit_status=$?
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
