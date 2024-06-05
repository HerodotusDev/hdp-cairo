#!/bin/bash

run_check() {
    local check_name="$1"
    local script_path="$2"
    
    echo "Running $check_name..."
    (source "$script_path")
    echo "$check_name completed successfully."
}

# Start time
start_time=$SECONDS

echo "Running CI Locally..."

# Run each check
run_check "Build Check" "./tools/make/build.sh"
run_check "Cairo Format Check" "./tools/make/cairo_format_check.sh"
run_check "Python Format Check" "./tools/make/python_format_check.sh"
run_check "Cairo Unit Tests" "./tools/make/cairo_tests.sh"
run_check "Full Flow Test" "./tools/make/full_flow_test.sh"

# End time
end_time=$SECONDS

# Calculate and print the total runtime
runtime=$((end_time - start_time))
echo "Total local CI Runtime: $runtime seconds."
