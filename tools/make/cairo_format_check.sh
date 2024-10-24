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
find ./src ./tests -name '*.cairo' ! -path "./src/cairo1/*" ! -path "./src/contracts/*" | parallel --halt soon,fail=1 format_file {}

# Capture the exit status of parallel for .cairo files
exit_status_cairo_files=$?

# Format Scarb workspace
echo "Formatting Scarb workspace..."
scarb fmt

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
