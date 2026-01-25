// ============================================================================
// EVM Module
// ============================================================================
// EVM proof helpers and constants for supported chains.
pub mod account;
pub mod block_receipt;
pub mod block_tx;
pub mod header;
pub mod log;
pub mod storage;

pub fn result_to_u256(result: Span<felt252>) -> u256 {
    u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
}

pub const ETHEREUM_MAINNET_CHAIN_ID: felt252 = 0x1;
pub const ETHEREUM_TESTNET_CHAIN_ID: felt252 = 0xaa36a7;
pub const OPTIMISM_MAINNET_CHAIN_ID: felt252 = 0xa;
pub const OPTIMISM_TESTNET_CHAIN_ID: felt252 = 0xaa37dc;

