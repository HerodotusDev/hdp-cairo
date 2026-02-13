# Starknet API

The Starknet API provides access to block headers and storage values. All functions live under `hdp_cairo::starknet::*`.

## Header methods

- `header_get_block_number`
- `header_get_state_root`
- `header_get_sequencer_address`
- `header_get_block_timestamp`
- `header_get_transaction_count`
- `header_get_transaction_commitment`
- `header_get_event_count`
- `header_get_event_commitment`
- `header_get_parent_block_hash`
- `header_get_state_diff_commitment`
- `header_get_state_diff_length`
- `header_get_l1_gas_price_in_wei`
- `header_get_l1_gas_price_in_fri`
- `header_get_l1_data_gas_price_in_wei`
- `header_get_l1_data_gas_price_in_fri`
- `header_get_receipts_commitment`
- `header_get_l1_data_mode`
- `header_get_protocol_version`

Source: `hdp_cairo/src/starknet/header.cairo`

Return type: all header getters return `felt252`.

## Storage method

- `storage_get_slot`

Source: `hdp_cairo/src/starknet/storage.cairo`

Return type: `felt252`.

## Chain ID constants

- `STARKNET_MAINNET_CHAIN_ID`
- `STARKNET_TESTNET_CHAIN_ID`

## Example

```cairo
use hdp_cairo::HDP;
use hdp_cairo::starknet::{STARKNET_MAINNET_CHAIN_ID, header::{HeaderImpl, HeaderKey}};

let key = HeaderKey { chain_id: STARKNET_MAINNET_CHAIN_ID, block_number: 1_000_000 };
let sequencer = hdp.starknet.header_get_sequencer_address(key);
```
