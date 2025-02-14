#!/bin/bash

# Resolve the absolute path of the compiled class file
compiled_class_path=$(realpath ../target/dev/examples_example_starkgate.compiled_contract_class.json)

# Check if the file exists
if [ ! -f "$compiled_class_path" ]; then
  echo "Error: Compiled class file not found at $compiled_class_path"
  exit 1
fi

# Read the contents of the file
compiled_class_content=$(<"$compiled_class_path")

# Define the JSON structure using jq
json_output=$(jq -n \
  --argjson compiled_class "$compiled_class_content" \
  '{
    "params": [],
    "compiled_class": $compiled_class
  }')

# Specify the output file name
output_file="hdp_input.json"

# Write the JSON to the file
echo "$json_output" > "$output_file"

echo "JSON file created: $output_file"
