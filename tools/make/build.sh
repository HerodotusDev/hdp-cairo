#!/bin/bash

process_cairo_file() {
    local cairo_file="$1"
    local filename=$(basename "$cairo_file" .cairo)
    local first_line=$(head -n 1 "$cairo_file")

    echo "Compiling $cairo_file using cairo-compile ..."
    
    # Compile the Cairo file
    if cairo-compile --cairo_path="packages/eth_essentials" "$cairo_file" --output "build/compiled_cairo_files/$filename.json"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully compiled $cairo_file"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to compile $cairo_file"
        return 1
    fi
}

# Export the function so it's available in subshells
export -f process_cairo_file

# Ensure the build directory exists
mkdir -p build/compiled_cairo_files

# Find Cairo files and process them in parallel
find ./src ./tests/cairo_programs ./packages/hdp_bootloader/bootloader ./packages/hdp_bootloader/builtin_selection -name "*.cairo" ! -path "./src/cairo1/*" | parallel --halt now,fail=1 process_cairo_file {}

# Capture the exit status of parallel
exit_status=$?

# Exit with the captured status
echo "Parallel execution exited with status: $exit_status"
exit $exit_status
