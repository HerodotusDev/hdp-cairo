#!/bin/bash

format_file() {
    local file="$1"
    
    echo "Formatting file: $file"
    
    # Attempt to format the file
    if cairo-format -i "$file"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully formatted: $file"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to format: $file"
        return 1
    fi
}

format_scarb_project() {
    local project_dir="$1"
    
    echo "Formatting Scarb project in: $project_dir"
    
    # Attempt to format the Scarb project
    if (cd "$project_dir" && scarb fmt); then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully formatted Scarb project in: $project_dir"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to format Scarb project in: $project_dir"
        return 1
    fi
}

# Export the functions so they're available in subshells
export -f format_file
export -f format_scarb_project

# Find all .cairo files under src/ and tests/ directories and format them in parallel
echo "Formatting .cairo files..."
find ./src ./tests ./packages/contract_bootloader/ ./packages/hdp_bootloader/ -name '*.cairo' ! -path "./src/cairo1/*" ! -path "./src/contracts/*" | parallel --halt soon,fail=1 format_file

# Find Scarb projects and execute format_scarb_project in each
# echo "Formatting Scarb projects..."
# find ./src/cairo1 ./src/contracts -mindepth 1 -maxdepth 1 -type d | parallel --halt now,fail=1 format_scarb_project

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
