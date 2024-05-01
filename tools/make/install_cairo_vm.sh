#!/bin/bash

# Clone the repository
git clone https://github.com/lambdaclass/cairo-vm.git

# Change directory to cairo-vm
cd cairo-vm || exit

# Checkout the specific commit
git checkout 2e24b6a15704e038f4a15dfdb89c13ab14cba569

# Change directory to cairo1-run
cd cairo1-run || exit

# Install the cargo package
cargo install --path .

# Move back to the previous directory
cd ../../
