# EVM Handlers

EVM handlers support headers, accounts, storage, transactions, receipts, and logs. They exist in both dry run and sound run variants.

## Implementations

- Dry run: `crates/dry_hint_processor/src/syscall_handler/evm/`
- Sound run: `crates/sound_hint_processor/src/syscall_handler/evm/`

## Key types

Handlers share key types defined in `crates/types/src/keys/evm/`:

- `HeaderKey` (chain_id, block_number)
- `AccountKey` (chain_id, block_number, address)
- `StorageKey` (chain_id, block_number, address, slot)
- `BlockTxKey` (chain_id, block_number, index)
- `BlockReceiptKey` (chain_id, block_number, index)
- `LogKey` (chain_id, block_number, tx_index, log_index)

## Contract address mapping

The Cairo syscall uses numeric `contract_address` values to select which handler to use:

- `0`: header
- `1`: account
- `2`: storage
- `3`: transaction
- `4`: receipt
- `5`: log

## Data sources

- **Dry run**: RPC calls fetch and decode data, then record keys.
- **Sound run**: values are decoded from memorizers filled during verification.

## Log handling

Logs are derived from receipt proofs. Log keys hash the same receipt label as receipts, and the sound run extracts log data from the verified receipt payload.
