#!/bin/bash

# Activate virtual environment
source venv/bin/activate

# Get the Cairo file from the command line argument
cairo_file="$1"
filename=$(basename "$cairo_file" .cairo)

# Define the log file path incorporating the filename
LOG_FILE="full_flow_${filename}.log"

# Ensure the log file exists, otherwise create it
touch "$LOG_FILE"

# Export the log file path to be available in subshells
export LOG_FILE
export filename

# Function to run tests on a given Cairo file
run_tests() {
    local input_file="$1"
    local temp_output=$(mktemp)

    # Attempt to run the compiled program and capture output
    local start_time=$(date +%s)
    cairo-run --program="build/compiled_cairo_files/hdp.json" --program_input=$input_file --layout=starknet_with_keccak >> "$temp_output" 2>&1
    local status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successful $input_file: Duration ${duration} seconds"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed: $input_file"
    fi

    cat "$temp_output" >> "$LOG_FILE"
    rm -f "$temp_output" # Clean up temporary file
    return $status
}

export -f run_tests


# Ensure the Cairo file is compiled before running parallel tests
echo "Compiling HDP Cairo file..."
cairo-compile --cairo_path="packages/eth_essentials" "src/hdp.cairo" --output "build/compiled_cairo_files/hdp.json"

# Clone the repository if the directory doesn't exist
if [ ! -d "hdp-test" ]; then
    git clone https://github.com/HerodotusDev/hdp-test
    cd hdp-test
    git checkout slr
    cd ../
fi

echo "Starting tests..."
find ./hdp-test/fixtures -name "input.json" | parallel run_tests $filename

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
