#!/usr/bin/env python3
"""
Verify that bytecode keys in proofs.json match computed Poseidon hashes.

This script:
1. Reads bytecode keys from proofs.json
2. Computes expected keys for HPECT1 and HPECT2 addresses
3. Compares them to verify key computation is correct
"""

import json
import sys
from pathlib import Path

# Try to import poseidon hash
try:
    from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
    from starkware.cairo.common.poseidon_hash import poseidon_hash_many
    HAS_STARKWARE = True
except ImportError:
    HAS_STARKWARE = False
    print("Warning: starkware not available, will only show expected parameters")

def compute_unconstrained_key(chain_id: int, block_number: int, address: int) -> str:
    """Compute unconstrained memorizer key using Poseidon hash."""
    if not HAS_STARKWARE:
        return None
    
    params = [chain_id, block_number, address]
    key = poseidon_hash_many(params)
    return hex(key)

def compute_evm_key(chain_id: int, block_number: int, address: int) -> str:
    """Compute EVM memorizer key using Poseidon hash."""
    if not HAS_STARKWARE:
        return None
    
    code_label = ord('c') + (ord('o') << 8) + (ord('d') << 16) + (ord('e') << 24)
    params = [chain_id, code_label, block_number, address]
    key = poseidon_hash_many(params)
    return hex(key)

def main():
    proofs_path = Path("proofs.json")
    if not proofs_path.exists():
        print(f"Error: {proofs_path} not found")
        print("Run 'hdp fetch-proofs' first")
        sys.exit(1)
    
    with open(proofs_path, 'r') as f:
        proofs = json.load(f)
    
    unconstrained = proofs.get('unconstrained', {})
    if not unconstrained:
        print("Error: No unconstrained data in proofs.json")
        sys.exit(1)
    
    # Test parameters
    HPECT1_ADDRESS = 0xe5d5bc62Cf36FB14eFd8c32238c5d39B15bbFFd1
    HPECT2_ADDRESS = 0x6c7853Cd36c9189c87CDD82655Da6d0d6e4df87f
    SEPOLIA_CHAIN_ID = 11155111
    BLOCK_NUMBER = 9689123
    
    print("=" * 80)
    print("Bytecode Key Verification")
    print("=" * 80)
    print()
    
    print(f"Chain ID: {SEPOLIA_CHAIN_ID}")
    print(f"Block Number: {BLOCK_NUMBER}")
    print(f"HPECT1 Address: {hex(HPECT1_ADDRESS)}")
    print(f"HPECT2 Address: {hex(HPECT2_ADDRESS)}")
    print()
    
    # Get keys from proofs.json
    proof_keys = list(unconstrained.keys())
    print(f"Found {len(proof_keys)} bytecode entries in proofs.json:")
    for i, key in enumerate(proof_keys, 1):
        bytecode = unconstrained[key].get('Bytecode', '')
        bytecode_len = len(bytecode) // 2  # Hex string, so divide by 2
        print(f"  {i}. Key: {key}")
        print(f"     Bytecode length: {bytecode_len} bytes")
        print()
    
    if not HAS_STARKWARE:
        print("=" * 80)
        print("Cannot compute keys (starkware not available)")
        print("=" * 80)
        print()
        print("Expected unconstrained key params:")
        print(f"  HPECT1: [{SEPOLIA_CHAIN_ID}, {BLOCK_NUMBER}, {HPECT1_ADDRESS}]")
        print(f"  HPECT2: [{SEPOLIA_CHAIN_ID}, {BLOCK_NUMBER}, {HPECT2_ADDRESS}]")
        print()
        print("Expected EVM key params:")
        code_label = ord('c') + (ord('o') << 8) + (ord('d') << 16) + (ord('e') << 24)
        print(f"  HPECT1: [{SEPOLIA_CHAIN_ID}, {code_label}, {BLOCK_NUMBER}, {HPECT1_ADDRESS}]")
        print(f"  HPECT2: [{SEPOLIA_CHAIN_ID}, {code_label}, {BLOCK_NUMBER}, {HPECT2_ADDRESS}]")
        return
    
    # Compute expected keys
    print("=" * 80)
    print("Computed Keys")
    print("=" * 80)
    print()
    
    # Unconstrained keys
    print("Unconstrained Memorizer Keys (poseidon_hash([chain_id, block_number, address])):")
    hpect1_unc_key = compute_unconstrained_key(SEPOLIA_CHAIN_ID, BLOCK_NUMBER, HPECT1_ADDRESS)
    hpect2_unc_key = compute_unconstrained_key(SEPOLIA_CHAIN_ID, BLOCK_NUMBER, HPECT2_ADDRESS)
    print(f"  HPECT1: {hpect1_unc_key}")
    print(f"  HPECT2: {hpect2_unc_key}")
    print()
    
    # EVM keys
    print("EVM Memorizer Keys (poseidon_hash([chain_id, 'code', block_number, address])):")
    hpect1_evm_key = compute_evm_key(SEPOLIA_CHAIN_ID, BLOCK_NUMBER, HPECT1_ADDRESS)
    hpect2_evm_key = compute_evm_key(SEPOLIA_CHAIN_ID, BLOCK_NUMBER, HPECT2_ADDRESS)
    print(f"  HPECT1: {hpect1_evm_key}")
    print(f"  HPECT2: {hpect2_evm_key}")
    print()
    
    # Compare
    print("=" * 80)
    print("Verification")
    print("=" * 80)
    print()
    
    hpect1_match = hpect1_unc_key in proof_keys
    hpect2_match = hpect2_unc_key in proof_keys
    
    print(f"HPECT1 unconstrained key in proofs.json: {'✓ MATCH' if hpect1_match else '✗ NOT FOUND'}")
    if hpect1_match:
        print(f"  Found at: {hpect1_unc_key}")
    else:
        print(f"  Expected: {hpect1_unc_key}")
        print(f"  Available keys: {proof_keys}")
    
    print()
    print(f"HPECT2 unconstrained key in proofs.json: {'✓ MATCH' if hpect2_match else '✗ NOT FOUND'}")
    if hpect2_match:
        print(f"  Found at: {hpect2_unc_key}")
    else:
        print(f"  Expected: {hpect2_unc_key}")
        print(f"  Available keys: {proof_keys}")
    
    if hpect1_match and hpect2_match:
        print()
        print("✓ All keys match! Key computation is correct.")
    else:
        print()
        print("✗ Key mismatch detected. Check key computation logic.")

if __name__ == "__main__":
    main()


