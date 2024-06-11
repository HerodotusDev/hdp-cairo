#!/bin/bash

format_file() {
    local file="$1"
    cairo-format -c "$file"
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - File $file is formatted correctly"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - File $file is not formatted correctly"
        return $status
    fi
}

format_scarb_project() {
    local project_dir="$1"
    (cd "$project_dir" && scarb fmt -c)
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $project_dir is formatted correctly"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $project_dir is not formatted correctly"
        return $status
    fi
}

# Export functions so they're available in subshells
export -f format_file
export -f format_scarb_project

# Find all .cairo files and format them in parallel
echo "Finding and formatting .cairo files..."
find ./src ./tests ./packages/contract_bootloader/ ./packages/hdp_bootloader/ -name '*.cairo' ! -path "./src/cairo1/*" ! -path "./src/contracts/*" | parallel --halt soon,fail=1 format_file

# Find Scarb projects and format them in parallel
echo "Finding and formatting Scarb projects..."
find ./src/cairo1 ./src/contracts -mindepth 1 -maxdepth 1 -type d | parallel --halt now,fail=1 format_scarb_project

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
