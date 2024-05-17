#!/bin/bash

mkdir -p build

# Clone the repository
git clone https://github.com/HerodotusDev/cairo-vm.git

cd cairo-vm

git checkout aecbb3f01dacb6d3f90256c808466c2c37606252

cd cairo1-run

cargo build --release

cd ../

cp target/release/cairo1-run ../build/

cd ../
