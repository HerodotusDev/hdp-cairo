# Unconstrained Data

Unconstrained data is used for large blobs (like EVM bytecode) that are too expensive to verify inline. Instead, HDP verifies a hash and then returns the raw data.

## Use case: EVM bytecode

The unconstrained memorizer returns bytecode and verifies it against the account code hash:

- Fetch bytecode during dry run and record a key
- During sound run, load the bytecode from memorizer
- Compute `keccak(bytecode)` and compare to `account_get_code_hash`

## Dry-run behavior

The dry-run handler fetches bytecode via RPC (`eth_getCode`) and stores it as `BytecodeLeWords` in the unconstrained key set.

`BytecodeLeWords` stores the bytecode as little-endian 64-bit words plus a final partial word.

## Cairo API

`hdp_cairo/src/unconstrained/state.cairo` exposes:

- `evm_account_get_bytecode(hdp, key)` -> `ByteCode`

If the hash check fails, execution halts with `Account: code hash mismatch`.
