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

use std::{fmt, str::FromStr};

pub use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
pub use cairo_vm::{vm::runners::cairo_pie::CairoPie, Felt252};
use param::Param;
use proofs::{evm, starknet};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;

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

#[derive(Debug, Serialize, Clone, PartialEq, Eq)]
pub enum ChainIds {
    EthereumMainnet,
    EthereumSepolia,
    StarknetMainnet,
    StarknetSepolia,
}

impl fmt::Display for ChainIds {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ChainIds::EthereumMainnet => write!(f, "ethereum-mainnet"),
            ChainIds::EthereumSepolia => write!(f, "ethereum-sepolia"),
            ChainIds::StarknetMainnet => write!(f, "starknet-mainnet"),
            ChainIds::StarknetSepolia => write!(f, "starknet-sepolia"),
        }
    }
}

impl FromStr for ChainIds {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "ethereum-mainnet" | "ethereum_mainnet" | "ethereummainnet" => Ok(Self::EthereumMainnet),
            "ethereum-sepolia" | "ethereum_sepolia" | "ethereumsepolia" => Ok(Self::EthereumSepolia),
            "starknet-mainnet" | "starknet_mainnet" | "starknetmainnet" => Ok(Self::StarknetMainnet),
            "starknet-sepolia" | "starknet_sepolia" | "starknetsepolia" => Ok(Self::StarknetSepolia),
            _ => Err(format!("Invalid chain ID: {}", s)),
        }
    }
}

impl ChainIds {
    pub fn from_u128(chain_id: u128) -> Option<Self> {
        match chain_id {
            ETHEREUM_MAINNET_CHAIN_ID => Some(Self::EthereumMainnet),
            ETHEREUM_TESTNET_CHAIN_ID => Some(Self::EthereumSepolia),
            STARKNET_MAINNET_CHAIN_ID => Some(Self::StarknetMainnet),
            STARKNET_TESTNET_CHAIN_ID => Some(Self::StarknetSepolia),
            _ => None,
        }
    }
}

impl<'de> Deserialize<'de> for ChainIds {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = Value::deserialize(deserializer)?;

        match value {
            Value::String(s) => ChainIds::from_str(&s).map_err(serde::de::Error::custom),
            Value::Number(n) => {
                if let Some(num) = n.as_u64() {
                    ChainIds::from_u128(num as u128).ok_or_else(|| serde::de::Error::custom(format!("invalid chain ID number: {}", num)))
                } else {
                    Err(serde::de::Error::custom("chain ID number out of range"))
                }
            }
            _ => Err(serde::de::Error::custom("chain ID must be a string or number")),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPDryRunOutput {
    pub program_hash: Felt252,
    pub result_low: Felt252,
    pub result_high: Felt252,
}

impl FromIterator<Felt252> for HDPDryRunOutput {
    fn from_iter<T: IntoIterator<Item = Felt252>>(iter: T) -> Self {
        let mut i = iter.into_iter();
        let program_hash = i.next().unwrap();
        let result_low = i.next().unwrap();
        let result_high = i.next().unwrap();

        Self {
            program_hash,
            result_low,
            result_high,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct MmrMetaOutput {
    pub id: Felt252,
    pub size: Felt252,
    pub chain_id: Felt252,
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

        while let Ok([id, size, chain_id, root]) = i.next_chunk::<4>() {
            mmr_metas.push(MmrMetaOutput { id, size, chain_id, root });
        }

        Self {
            program_hash,
            result_low,
            result_high,
            mmr_metas,
        }
    }
}

impl HDPOutput {
    pub fn to_felt_vec(&self) -> Vec<Felt252> {
        let mut felt_vec = vec![self.program_hash, self.result_low, self.result_high];
        self.mmr_metas.iter().for_each(|mmr_meta| {
            felt_vec.extend([mmr_meta.id, mmr_meta.size, mmr_meta.chain_id, mmr_meta.root]);
        });
        felt_vec
    }
}
