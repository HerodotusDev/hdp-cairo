#!/bin/bash

process_cairo_file() {
    local cairo_file="$1"
    local filename=$(basename "$cairo_file" .cairo)
    local first_line=$(head -n 1 "$cairo_file")

    echo "Compiling $cairo_file using cairo-compile ..."
    cairo-compile --cairo_path="packages/eth_essentials" "$cairo_file" --output "build/compiled_cairo_files/$filename.json"
    
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully compiled $1"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to compile $1"
        return $status
    fi
}

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
export -f process_cairo_file
export -f process_scarb_project

# Use --halt now,fail=1 to return non-zero if any task fails
find ./src ./tests/cairo_programs ./packages/hdp_bootloader/bootloader ./packages/hdp_bootloader/builtin_selection -name "*.cairo" ! -path "./tests/cairo_programs/cairo1_programs/*" | parallel --halt now,fail=1 process_cairo_file

# Find scarb projects and execute process_scarb_project in each
find ./tests/cairo_programs/cairo1_programs -mindepth 1 -maxdepth 1 -type d | parallel --halt now,fail=1 process_scarb_project

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
