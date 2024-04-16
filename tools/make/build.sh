#!/bin/bash

process_cairo_file() {
    local cairo_file="$1"
    local filename=$(basename "$cairo_file" .cairo)
    local first_line=$(head -n 1 "$cairo_file")

    echo "Compiling $cairo_file using cairo-compile ..."
    cairo-compile --cairo_path="packages/evm_libs_cairo" "$cairo_file" --output "build/compiled_cairo_files/$filename.json"
    
    local status=$?
    if [ $status -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully compiled $1"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to compile $1"
        return $status
    fi
}

export -f process_cairo_file

# Use --halt now,fail=1 to return non-zero if any task fails
find ./src ./tests/cairo_programs -name "*.cairo" | parallel --halt now,fail=1 process_cairo_file

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
