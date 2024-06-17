#!/bin/bash

run_check() {
    local check_name="$1"
    local script_path="$2"
    
    echo "Running $check_name..."
<<<<<<< HEAD
    echo "Script path: $script_path"
    
    # Attempt to execute the script
    if [ -x "$script_path" ]; then
        "$script_path"
        local check_exit_code=$?
        
        if [ $check_exit_code -ne 0 ]; then
            echo "$check_name failed with exit code $check_exit_code."
            exit $check_exit_code
        else
            echo "$check_name completed successfully."
        fi
    else
        echo "Error: Script $script_path is not executable or does not exist."
        exit 1
=======
    source "$script_path"
    local check_exit_code=$?
    
    if [ $check_exit_code -ne 0 ]; then
        echo "$check_name failed with exit code $check_exit_code."
        exit $check_exit_code
    else
        echo "$check_name completed successfully."
>>>>>>> feat/dockerize
    fi
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

echo "All checks passed successfully."
