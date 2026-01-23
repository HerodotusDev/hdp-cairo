# Memorizers

Memorizers are Cairo0 dictionaries that store verified data for fast lookup during the sound run. Each memorizer maps a hashed key to encoded values.

## Why memorizers?

- Keep the sound run fully offline
- Allow deterministic reads in Cairo1
- Separate verification from execution

## Key hashing

Key hashing must be consistent across Cairo and Rust. For EVM keys, the system uses Poseidon hashing:

```
// Cairo: src/memorizers/evm/memorizer.cairo
let hash = poseidon_hash_many([chain_id, block_number, address, ...]);

// Rust: crates/types/src/keys/evm/header.rs (similar pattern)
poseidon_hash_many(&[chain_id, block_number, ...])
```

If the hash differs, the sound run will not find the requested data.

For transaction and receipt keys, the hash includes a label (`'block_tx'` or `'block_receipt'`) to avoid collisions with other key types.

## Memorizer types

- **EVM**: header, account, storage, transaction, receipt, log
- **Starknet**: header, storage
- **Injected state**: Patricia-trie-backed custom state
- **Unconstrained**: bytecode retrieval with code-hash validation

## Implementation references

- `src/memorizers/evm/memorizer.cairo`
- `src/memorizers/starknet/memorizer.cairo`
- `src/memorizers/injected_state/memorizer.cairo`
- `src/memorizers/unconstrained/memorizer.cairo`
