#!/bin/bash
set -e

# HPECT1 Basic Tests (Math + Delegate Call)
# Chain: Sepolia (11155111)
# Block: 9689123

echo "=== HPECT1 Basic Tests ==="
echo ""

cd "$(dirname "$0")/../.."

# Build
echo "Building..."
scarb build -p example_hpect1_basic_tests

echo "✅ Build complete"
echo ""

# Dry run
echo "Running dry-run..."
hdp dry-run \
    -m target/dev/example_hpect1_basic_tests_module.compiled_contract_class.json \
    --print_output

echo "✅ Dry run complete"
echo ""

# Fetch proofs
echo "Fetching proofs..."
hdp fetch-proofs

echo "✅ Proofs fetched"
echo ""

# Sound run
echo "Executing with verified data..."
hdp sound-run \
    -m target/dev/example_hpect1_basic_tests_module.compiled_contract_class.json \
    --print_output

echo ""
echo "=== Complete ==="
