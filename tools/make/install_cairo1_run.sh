#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print an error message and exit
function error_exit {
  echo "$1" 1>&2
  exit 1
}

# Function to print a message and exit
function message_exit {
  echo "$1"
  exit 0
}

# Clone the repository if it doesn't exist
REPO_URL="https://github.com/HerodotusDev/cairo-vm.git"
REPO_DIR="cairo-vm"
COMMIT_HASH="aecbb3f01dacb6d3f90256c808466c2c37606252"
CARGO_DIR="cairo1-run"

# Check if the repository directory already exists
if [ -d "$REPO_DIR" ]; then
  message_exit "Repository directory $REPO_DIR already exists. Script aborted."
fi

# Clone the repository
echo "Cloning repository from $REPO_URL..."
if ! git clone "$REPO_URL"; then
  error_exit "Failed to clone repository."
fi

# Change directory to the repository
cd "$REPO_DIR" || error_exit "Failed to change directory to $REPO_DIR."

# Checkout the specified commit
echo "Checking out commit $COMMIT_HASH..."
if ! git checkout "$COMMIT_HASH"; then
  error_exit "Failed to checkout commit $COMMIT_HASH."
fi

# Change directory to the specified subdirectory
cd "$CARGO_DIR" || error_exit "Failed to change directory to $CARGO_DIR."

# Install the cargo package
echo "Installing cargo package..."
if ! cargo install --path .; then
  error_exit "Cargo install failed."
fi

# Move back to the previous directory
cd - > /dev/null

echo "Script completed successfully."
