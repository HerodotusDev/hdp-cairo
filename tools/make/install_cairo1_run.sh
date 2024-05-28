#!/bin/bash

# Clone the repository
git clone https://github.com/HerodotusDev/cairo-vm.git

git checkout aecbb3f01dacb6d3f90256c808466c2c37606252

# Change directory to cairo-vm
cd cairo-vm/cairo1-run || exit

# Install the cargo package
cargo install --path .

# Move back to the previous directory
cd ../../