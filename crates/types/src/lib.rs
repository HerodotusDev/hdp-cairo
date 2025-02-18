#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]
#![feature(iter_next_chunk)]

pub mod cairo;
pub mod error;
pub mod keys;
pub mod param;
pub mod proofs;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::Felt252;
use param::Param;
use proofs::{evm, starknet};
use serde::{Deserialize, Serialize};

pub const RPC_URL_ETHEREUM: &str = "RPC_URL_ETHEREUM";
pub const RPC_URL_HERODOTUS_INDEXER: &str = "RPC_URL_HERODOTUS_INDEXER";
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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct MmrMetaOutput {
    pub id: Felt252,
    pub size: Felt252,
    pub root: Felt252,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPOutput {
    pub program_hash: Felt252,
    pub result_low: Felt252,
    pub result_high: Felt252,
    pub mmr_metas: Vec<MmrMetaOutput>,
}

impl FromIterator<Felt252> for HDPOutput {
    fn from_iter<T: IntoIterator<Item = Felt252>>(iter: T) -> Self {
        let mut i = iter.into_iter();
        let program_hash = i.next().unwrap();
        let result_low = i.next().unwrap();
        let result_high = i.next().unwrap();

        let mut mmr_metas = Vec::<MmrMetaOutput>::new();

        while let Ok([id, root, size]) = i.next_chunk::<3>() {
            mmr_metas.push(MmrMetaOutput { id, root, size });
        }

        Self {
            program_hash,
            result_low,
            result_high,
            mmr_metas,
        }
    }
}
