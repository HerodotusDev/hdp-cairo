# HPECT1 Contract Test Suite

This module tests all 31 functions of the HPECT1 Solidity contract using HDP's provable eth_call functionality.

## Functions Tested

### Basic Getters
1. `getConstantNumber()` - Returns constant 2137
2. `getHardcodedNumber()` - Returns hardcoded 2137
3. `getStorageNumber()` - Returns value from storage

### Arithmetic Operations
4. `performArithmeticOperations(a, b)` - Add, sub, mul, div
5. `performExponentiation(base, exp)` - Power operation
6. `performModuloOperation(a, b)` - Modulo operation

### Bitwise Operations
7. `performBitwiseOperations(a, b)` - AND, OR, XOR, NOT
8. `performShiftOperations(a, b)` - Left/right shift

### Cryptographic Operations
9. `performKeccak256Hash()` - Keccak256 hashing
10. `performIdentity()` - Identity precompile
11. `performEcrecover()` - ECDSA recovery
12. `performModexp()` - Modular exponentiation

### Storage Operations
13. `performStorageOperations()` - SLOAD/SSTORE
14. `calculateWithStorageNumber()` - Compute with storage
15. `getStorageMapping(key)` - Mapping access

### String Operations
16. `getConstantString()` - Returns constant string
17. `getHardcodedString()` - Returns hardcoded string
18. `getStorageString()` - Returns string from storage

### Complex Calculations
19. `performComplexCalculation()` - Multi-step calculation
20. `calculateWithConstant()` - Calculate using constant

### Call Operations (including Delegate Calls)
21. `performStaticCall()` - Static call to another contract
22. `performDelegateCall()` - Delegate call to HPECT2
23. `performDelegateCallWithReturn()` - Delegate call with return value
24. `getCallerAddressViaHPECT2()` - Get caller via delegate call
25. `calculateWithHPECT2Number()` - Calculate using HPECT2's number

### Error Handling
26. `performAssertOperation()` - Assert statement
27. `performRevertOperation()` - Revert statement

### Additional Tests
28. `calculateWithConstantString()` - String-based calculation
29. `calculateWithStorageString()` - Storage string calculation
30. `calculateWithStorageMapping()` - Mapping-based calculation
31. `performKeccak256WithStorage()` - Hash with storage data

## Usage

### Quick Run

```bash
./run.sh
```

Uses Sepolia testnet block 9689123.

### Manual Steps

```bash
# 1. Build the module
scarb build -p example_hpect1_tests

# 2. Dry run to identify required data
hdp dry-run -m target/dev/example_hpect1_tests_module.compiled_contract_class.json --print_output

# 3. Fetch and verify on-chain data
hdp fetch-proofs

# 4. Execute with verified data
hdp sound-run -m target/dev/example_hpect1_tests_module.compiled_contract_class.json --print_output
```

## HDP Workflow

```
┌─────────────────────────────────────────────────┐
│ 1. scarb build                                  │
│    Compiles Cairo 1 module to contract class    │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 2. hdp dry-run                                  │
│    Identifies required on-chain data:           │
│    - Contract bytecode                          │
│    - Storage slots                              │
│    - Account state                              │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 3. hdp fetch-proofs                             │
│    Fetches from Ethereum RPC:                   │
│    - Merkle proofs                              │
│    - RLP-encoded data                           │
│    - Verification data                          │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│ 4. hdp sound-run                                │
│    Executes with verified data:                 │
│    - Verifies all proofs                        │
│    - Populates memorizers                       │
│    - Runs Cairo module                          │
│    - Generates ZK proof (PIE file)              │
└─────────────────────────────────────────────────┘
```

## Expected Output

```
=== HPECT1 Contract Test Suite ===
Block: 19000000

Test: getConstantNumber - PASSED
Test: getHardcodedNumber - PASSED
Test: getStorageNumber - PASSED
Test: performArithmeticOperations - PASSED
Test: performExponentiation - PASSED
...

=== Test Summary ===
Passed: 27
Failed: 4
Total:  31
```

Note: Some tests (delegate calls) may fail if HPECT2 contract is not deployed or accessible.

## Configuration

- **Chain**: Sepolia Testnet (Chain ID: 11155111)
- **Block**: 9689123
- **HPECT1**: `0xe5d5bc62Cf36FB14eFd8c32238c5d39B15bbFFd1`
- **HPECT2**: Required for delegate call tests (must be deployed on Sepolia)

## Requirements

- HDP CLI installed and configured
- Ethereum RPC endpoint configured
- Cairo/Scarb toolchain installed

## Troubleshooting

### Build Fails
- Ensure `scarb` is installed and in PATH
- Check that workspace dependencies are available
- Verify `hdp_cairo` is accessible

### Dry Run Fails
- Check that HDP is properly configured
- Verify contract addresses are correct
- Ensure block number is valid

### Fetch Proofs Fails
- Check RPC endpoint configuration
- Verify network connectivity
- Ensure contract exists at the specified block

### Sound Run Fails
- Review dry-run output for missing data
- Check that all proofs were fetched
- Verify memorizer key computations match

