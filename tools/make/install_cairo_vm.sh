#!/bin/bash

# Clone the repository
git clone https://github.com/HerodotusDev/cairo-vm.git

# Change directory to cairo-vm
cd cairo-vm/cairo1-run || exit

# Install the cargo package
cargo install --path .

# Move back to the previous directory
cd ../../
