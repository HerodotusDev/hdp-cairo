#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

pub mod cairo;
pub mod error;
pub mod keys;
pub mod param;
pub mod proofs;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use param::Param;
use proofs::{evm, starknet};
use serde::{Deserialize, Serialize};

pub const RPC_URL_ETHEREUM: &str = "RPC_URL_ETHEREUM";
pub const RPC_URL_HERODOTUS_INDEXER_GROWER: &str = "RPC_URL_HERODOTUS_INDEXER_GROWER";
pub const RPC_URL_HERODOTUS_INDEXER_STAGING: &str = "RPC_URL_HERODOTUS_INDEXER_STAGING";
pub const RPC_URL_STARKNET: &str = "RPC_URL_STARKNET";

pub const ETHEREUM_MAINNET_CHAIN_ID: u128 = 0x1;
pub const ETHEREUM_TESTNET_CHAIN_ID: u128 = 0xaa36a7;
pub const STARKNET_MAINNET_CHAIN_ID: u128 = 0x534e5f4d41494e;
pub const STARKNET_TESTNET_CHAIN_ID: u128 = 0x534e5f5345504f4c4941;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPDryRunInput {
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPInput {
    pub chain_proofs: Vec<ChainProofs>,
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ChainProofs {
    EthereumMainnet(evm::Proofs),
    EthereumSepolia(evm::Proofs),
    StarknetMainnet(starknet::Proofs),
    StarknetSepolia(starknet::Proofs),
}

impl ChainProofs {
    pub fn chain_id(&self) -> u128 {
        match self {
            ChainProofs::EthereumMainnet(_) => 0x1,
            ChainProofs::EthereumSepolia(_) => 0xaa36a7,
            ChainProofs::StarknetMainnet(_) => 0x534e5f4d41494e,
            ChainProofs::StarknetSepolia(_) => 0x534e5f5345504f4c4941,
        }
    }
}
