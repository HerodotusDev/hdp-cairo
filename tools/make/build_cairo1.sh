#!/bin/bash

process_scarb_project() {
    local project_dir="$1"
    local build_dir="build/compiled_cairo_files"
    
    echo "Building Scarb project in $project_dir"
    
    # Change to the project directory and build the project
    if (cd "$project_dir" && scarb build); then
        echo "Copying built files from $project_dir/target/dev to $build_dir"
        if cp "$project_dir/target/dev/"* "$build_dir/"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully built and copied files for Scarb project in $project_dir"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Built Scarb project in $project_dir, but failed to copy files"
            return 1
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to build Scarb project in $project_dir"
        return 1
    fi
}

# Export the function so it's available in subshells
export -f process_scarb_project

# Ensure the build directory exists
mkdir -p build/compiled_cairo_files

# Find Scarb projects and execute process_scarb_project in each
find ./src/cairo1 -mindepth 1 -maxdepth 1 -type d | parallel --halt now,fail=1 process_scarb_project {}

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
