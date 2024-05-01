#!/bin/bash

# Function to format a file and print a message based on the outcome
format_file() {
    cairo-format -i "$1"
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully formatted $1"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to format $1"
        return $status
    fi
}

format_scarb_project() {
    local project_dir="$1"
    
    echo "Formatting scarb project in $project_dir"
    (cd "$project_dir" && scarb fmt)
    
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully formatted scarb project in $project_dir"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to format scarb project in $project_dir"
    fi
}

# Export the function so it's available in subshells
export -f format_file
export -f format_scarb_project

# Find all .cairo files under src/ and tests/ directories and format them in parallel
# Using --halt soon,fail=1 to stop at the first failure
find ./src ./tests ./packages/hdp_bootloader/bootloader ./packages/hdp_bootloader/builtin_selection -name '*.cairo' ! -path "./tests/cairo_programs/cairo1_programs/*" | parallel --halt soon,fail=1 format_file

# Find scarb projects and execute format_scarb_project in each
find ./tests/cairo_programs/cairo1_programs -mindepth 1 -maxdepth 1 -type d | parallel --halt now,fail=1 format_scarb_project

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
