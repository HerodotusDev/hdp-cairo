# Starknet Handlers

Starknet handlers provide access to block headers and storage values.

## Implementations

- Dry run: `crates/dry_hint_processor/src/syscall_handler/starknet/`
- Sound run: `crates/sound_hint_processor/src/syscall_handler/starknet/`

## Key types

Key types live in `crates/types/src/keys/starknet/`:

- `HeaderKey` (chain_id, block_number)
- `StorageKey` (chain_id, block_number, address, storage_slot)

## Contract address mapping

The Cairo syscall uses numeric `contract_address` values to select which handler to use:

- `0`: header
- `1`: storage

## Data sources

- **Dry run**: Starknet RPC reads and key collection.
- **Sound run**: memorizer reads populated during verification.
