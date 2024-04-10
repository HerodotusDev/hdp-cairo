#!/bin/bash

run_tests() {
    local cairo_file="$1"
    local filename=$(basename "$cairo_file" .cairo)
    local temp_output=$(mktemp)

    # Redirecting output to temp file for potential error capture
    cairo-compile "$cairo_file" --output "build/compiled_cairo_files/$filename.json" > "$temp_output" 2>&1
    cairo-run --program="build/compiled_cairo_files/$filename.json" --layout=starknet_with_keccak >> "$temp_output" 2>&1
    local status=$?

    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Test Successful $1"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Test Failed $1"
        cat "$temp_output" # Display the captured output on failure
        rm -f "$temp_output"
        return $status
    fi

    rm -f "$temp_output"
}

source venv/bin/activate

# Export the function so it's available in subshells
export -f run_tests

# Find all .cairo files under src/ and tests/ directories and format them in parallel
# Using --halt soon,fail=1 to stop at the first failure
find ./tests/cairo_programs ./tests/hdp -name '*.cairo' ! -name 'test_vectors.cairo' | parallel --halt soon,fail=1 run_tests

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status