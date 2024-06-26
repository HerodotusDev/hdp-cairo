#!/bin/bash

# Check if the user provided an input argument
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path_to_contract_class_json>"
  exit 1
fi

# Get the input argument
CONTRACT_CLASS_JSON_PATH="$1"

# Define the output file
OUTPUT_FILE="contract_sierra.json"

# Run the starknet-sierra-compile command
starknet-sierra-compile "$CONTRACT_CLASS_JSON_PATH" "$OUTPUT_FILE" --add-pythonic-hints

# Check if the command was successful
if [ $? -eq 0 ]; then
  echo "Compilation successful. Output saved to $OUTPUT_FILE."
else
  echo "Compilation failed."
fi
