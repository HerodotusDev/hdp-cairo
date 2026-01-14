#!/bin/bash
set -e

# HPECT1 Contract Test Suite
# Chain: Sepolia (11155111)
# Block: 9689123
# Contract: 0xe5d5bc62Cf36FB14eFd8c32238c5d39B15bbFFd1
#
# This script runs the complete HDP workflow:
# 1. scarb build - Compile the Cairo 1 module
# 2. hdp dry-run - Identify required on-chain data
# 3. hdp fetch-proofs - Fetch and verify on-chain data
# 4. hdp sound-run - Execute with verified data and generate proof

echo "=== HPECT1 Contract Test Suite ==="
echo "Chain: Sepolia (11155111)"
echo "Block: 9689123"
echo "Contract: 0xe5d5bc62Cf36FB14eFd8c32238c5d39B15bbFFd1"
echo ""

# Navigate to hdp-cairo root
cd "$(dirname "$0")/../.."

# Step 1: Build the module
echo "Step 1: Building Cairo 1 module..."
scarb build -p example_hpect1_tests

if [ ! -f "target/dev/example_hpect1_tests_module.compiled_contract_class.json" ]; then
    echo "❌ Build failed!"
    exit 1
fi
echo "✅ Build successful"
echo ""

# Step 2: Dry run to identify required data
echo "Step 2: Running dry-run to identify required data..."
hdp dry-run \
    -m target/dev/example_hpect1_tests_module.compiled_contract_class.json \
    --print_output

echo "✅ Dry run complete"
echo ""

# Step 3: Fetch proofs
echo "Step 3: Fetching and verifying on-chain data..."
hdp fetch-proofs

echo "✅ Proofs fetched"
echo ""

# Step 4: Sound run with verified data
echo "Step 4: Executing with verified data..."
hdp sound-run \
    -m target/dev/example_hpect1_tests_module.compiled_contract_class.json \
    --print_output \
    --cairo_pie ./hpect1_tests_pie.zip

echo ""
echo "=== Test Suite Complete ==="
echo "PIE file: ./hpect1_tests_pie.zip"

