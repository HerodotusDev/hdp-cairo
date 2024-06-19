#!/bin/bash

echo "Checking code formatting with black..."
if black --check src/ tests/ tools/ packages/ setup.py; then
    echo "Code formatting check passed."
else
    echo "Code formatting check failed."
    exit 1
fi
