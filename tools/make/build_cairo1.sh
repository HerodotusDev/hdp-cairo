#!/bin/bash

process_scarb_project() {
    local project_dir="$1"
    
    echo "Building scarb project in $project_dir"
    (cd "$project_dir" && scarb build)
    cp "$project_dir/target/dev/"* "build/compiled_cairo_files/"
    
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully built scarb project in $project_dir"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to build scarb project in $project_dir"
    fi
}

# Export the function so it's available in subshells
export -f process_scarb_project

# Find scarb projects and execute process_scarb_project in each
find ./src/cairo1 -mindepth 1 -maxdepth 1 -type d | parallel --halt now,fail=1 process_scarb_project

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
