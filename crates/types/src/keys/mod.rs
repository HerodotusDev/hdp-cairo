use config::{ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID};

pub mod evm;
pub mod starknet;

pub enum KeyType {
    EVM,
    STARKNET,
}

impl From<u128> for KeyType {
    fn from(chain_id: u128) -> Self {
        match chain_id {
            STARKNET_MAINNET_CHAIN_ID => Self::STARKNET,
            STARKNET_TESTNET_CHAIN_ID => Self::STARKNET,
            ETHEREUM_MAINNET_CHAIN_ID => Self::EVM,
            ETHEREUM_TESTNET_CHAIN_ID => Self::EVM,
            _ => panic!("Unknown chain id: {}", chain_id),
        }
    }
}