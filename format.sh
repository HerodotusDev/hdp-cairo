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

# Export the functions so they're available in subshells
export -f format_file

# Find all .cairo files under src/ and tests/ directories and format them in parallel
echo "Formatting .cairo files..."
find ./src -name '*.cairo' | parallel --halt soon,fail=1 format_file {}
