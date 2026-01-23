# EVM API

The EVM API provides access to headers, accounts, storage, transactions, receipts, and logs. All functions live under `hdp_cairo::evm::*`.

## Keys

- `HeaderKey { chain_id, block_number }`
- `AccountKey { chain_id, block_number, address }`
- `StorageKey { chain_id, block_number, address, storage_slot }`
- `BlockTxKey { chain_id, block_number, transaction_index }`
- `BlockReceiptKey { chain_id, block_number, transaction_index }`
- `LogKey { chain_id, block_number, transaction_index, log_index }`

Chain ID constants:

- `ETHEREUM_MAINNET_CHAIN_ID`
- `ETHEREUM_TESTNET_CHAIN_ID`
- `OPTIMISM_MAINNET_CHAIN_ID`
- `OPTIMISM_TESTNET_CHAIN_ID`

## Header methods

Available getters:

- `header_get_parent`
- `header_get_uncle`
- `header_get_coinbase`
- `header_get_state_root`
- `header_get_transaction_root`
- `header_get_receipt_root`
- `header_get_bloom`
- `header_get_difficulty`
- `header_get_number`
- `header_get_gas_limit`
- `header_get_gas_used`
- `header_get_timestamp`
- `header_get_mix_hash`
- `header_get_nonce`
- `header_get_base_fee_per_gas`
- `header_get_blob_gas_used`
- `header_get_excess_blob_gas`
- `header_get_requests_hash`

Source: `hdp_cairo/src/evm/header.cairo`

Return types:

- Most header getters return `u256`.
- `header_get_bloom` returns a `ByteArray` (logs bloom).

Not yet exposed:

- `header_get_extra_data`
- `header_get_withdrawals_root`
- `header_get_parent_beacon_block_root`

## Account methods

- `account_get_nonce`
- `account_get_balance`
- `account_get_state_root`
- `account_get_code_hash`

Source: `hdp_cairo/src/evm/account.cairo`

Return types: all account getters return `u256`.

## Storage methods

- `storage_get_slot`

Source: `hdp_cairo/src/evm/storage.cairo`

Return type: `u256`.

## Transaction methods

- `block_tx_get_nonce`
- `block_tx_get_gas_price`
- `block_tx_get_gas_limit`
- `block_tx_get_receiver`
- `block_tx_get_value`
- `block_tx_get_v`
- `block_tx_get_r`
- `block_tx_get_s`
- `block_tx_get_chain_id`
- `block_tx_get_max_fee_per_gas`
- `block_tx_get_max_priority_fee_per_gas`
- `block_tx_get_max_fee_per_blob_gas`
- `block_tx_get_tx_type`
- `block_tx_get_sender`
- `block_tx_get_hash`

Source: `hdp_cairo/src/evm/block_tx.cairo`

Return types: all transaction getters return `u256`.

Not yet exposed:

- `block_tx_get_input`
- `block_tx_get_access_list`
- `block_tx_get_blob_versioned_hashes`
- `block_tx_get_authorization_list`

## Receipt methods

- `block_receipt_get_status`
- `block_receipt_get_cumulative_gas_used`
- `block_receipt_get_bloom`

Source: `hdp_cairo/src/evm/block_receipt.cairo`

Return types:

- Status and gas used return `u256`.
- `block_receipt_get_bloom` returns a `ByteArray`.

## Log methods

- `log_get_address`
- `log_get_topic0`
- `log_get_topic1`
- `log_get_topic2`
- `log_get_topic3`
- `log_get_topic4`
- `log_get_data`

Source: `hdp_cairo/src/evm/log.cairo`

Return types:

- Address and topics return `u256`.
- `log_get_data` returns `Array<u128>`.

## Example

```cairo
use hdp_cairo::HDP;
use hdp_cairo::evm::{ETHEREUM_MAINNET_CHAIN_ID, account::{AccountImpl, AccountKey}};

let key = AccountKey {
    chain_id: ETHEREUM_MAINNET_CHAIN_ID,
    block_number: 18_500_000,
    address: 0x1234,
};

let balance = hdp.evm.account_get_balance(key);
```
