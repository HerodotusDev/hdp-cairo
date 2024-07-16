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
find ./src ./tests ./packages/contract_bootloader/ ./packages/hdp_bootloader/ -name '*.cairo' ! -path "./src/cairo1/*" ! -path "./src/contracts/*" | parallel --halt soon,fail=1 format_file {}

# Capture the exit status of parallel for .cairo files
exit_status_cairo_files=$?

# Format Scarb workspace
echo "Formatting Scarb workspace..."
scarb fmt --check

# Capture the exit status of parallel for Scarb projects
exit_status_scarb_projects=$?

# Determine the final exit status
if [ $exit_status_cairo_files -ne 0 ] || [ $exit_status_scarb_projects -ne 0 ]; then
    final_exit_status=1
else
    final_exit_status=0
fi

# Exit with the determined status
echo "Parallel execution exited with status: $final_exit_status"
exit $final_exit_status
