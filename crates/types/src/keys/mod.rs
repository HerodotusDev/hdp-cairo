use crate::{
    ChainId, ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID,
    STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
};

pub mod evm;
pub mod injected_state;
pub mod starknet;

pub enum KeyType {
    EVM,
    STARKNET,
    Unknown(ChainId),
}

impl From<ChainId> for KeyType {
    fn from(chain_id: ChainId) -> Self {
        match chain_id {
            STARKNET_MAINNET_CHAIN_ID => Self::STARKNET,
            STARKNET_TESTNET_CHAIN_ID => Self::STARKNET,
            ETHEREUM_MAINNET_CHAIN_ID => Self::EVM,
            ETHEREUM_TESTNET_CHAIN_ID => Self::EVM,
            OPTIMISM_MAINNET_CHAIN_ID => Self::EVM,
            OPTIMISM_TESTNET_CHAIN_ID => Self::EVM,
            other => Self::Unknown(other),
        }
    }
}
