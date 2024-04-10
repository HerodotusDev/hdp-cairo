#!/bin/bash
set -e

# Start time
start_time=$SECONDS

echo "Running CI Locally..."

echo "Run Build Check..."
(source ./tools/make/build.sh)

echo "Run Cairo Format Check..."
(source ./tools/make/cairo_format_check.sh)

echo "Run Python Format Check..."
(source ./tools/make/python_format_check.sh)

echo "Run Cairo Tests..."
(source ./tools/make/cairo_tests.sh)

# End time
end_time=$SECONDS

echo "All checks passed successfully!"

# Calculate and print the total runtime
runtime=$((end_time - start_time))
echo "Total local CI Runtime: $runtime seconds."