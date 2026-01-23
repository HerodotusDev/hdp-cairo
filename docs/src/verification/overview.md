# Verification Overview

Verification happens inside Cairo0 during the sound run. It ensures that all values used by your module are backed by valid proofs.

## Verification order

1. **Headers** are verified against MMR peaks (trusted roots).
2. **Accounts** are verified against the header `state_root`.
3. **Storage** is verified against the account `storage_root`.
4. **Transactions and receipts** are verified against block roots.

This order matters because each step depends on the root validated by the previous step.

## Verification cascade

```
MMR Meta -> Headers -> Accounts -> Storage
             state_root     storage_root
```

## Where this lives

- `src/verifiers/` contains Cairo0 verifiers.
- `crates/hints/src/verifiers/` provides supporting hint logic.

Hints bridge complex operations (like RLP decoding or trie traversal) into Rust while keeping the verification logic inside Cairo0.
