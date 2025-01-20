#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

pub mod cairo;
pub mod keys;
pub mod param;
pub mod proofs;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use param::Param;
use proofs::{evm, starknet};
use serde::{Deserialize, Serialize};

pub const ETH_RPC: &str = "ETH_RPC";
pub const STARKNET_RPC: &str = "STARKNET_RPC";
pub const FEEDER_GATEWAY: &str = "FEEDER_GATEWAY";
pub const HERODOTUS_INDEXER_RPC: &str = "HERODOTUS_INDEXER_RPC";

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
