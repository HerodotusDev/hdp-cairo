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

use alloy::primitives::map::HashMap;
pub use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
pub use cairo_vm::{vm::runners::cairo_pie::CairoPie, Felt252};
use param::Param;
use proofs::{evm, injected_state::StateProofs, starknet};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;

pub const RPC_URL_ETHEREUM_MAINNET: &str = "RPC_URL_ETHEREUM_MAINNET";
pub const RPC_URL_ETHEREUM_TESTNET: &str = "RPC_URL_ETHEREUM_TESTNET";

pub const RPC_URL_OPTIMISM_MAINNET: &str = "RPC_URL_OPTIMISM_MAINNET";
pub const RPC_URL_OPTIMISM_TESTNET: &str = "RPC_URL_OPTIMISM_TESTNET";

pub const RPC_URL_STARKNET_MAINNET: &str = "RPC_URL_STARKNET_MAINNET";
pub const RPC_URL_STARKNET_TESTNET: &str = "RPC_URL_STARKNET_TESTNET";

pub const RPC_URL_HERODOTUS_INDEXER: &str = "RPC_URL_HERODOTUS_INDEXER";

/// Enum for available hashing functions
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Default, Copy)]
#[serde(rename_all = "lowercase")]
pub enum HashingFunction {
    #[default]
    Poseidon,
    Keccak,
    // Pedersen,
}

pub const ETHEREUM_MAINNET_CHAIN_ID: u128 = 0x1;
pub const ETHEREUM_TESTNET_CHAIN_ID: u128 = 0xaa36a7;
pub const OPTIMISM_MAINNET_CHAIN_ID: u128 = 0xa;
pub const OPTIMISM_TESTNET_CHAIN_ID: u128 = 0xaa37dc;
pub const STARKNET_MAINNET_CHAIN_ID: u128 = 0x534e5f4d41494e;
pub const STARKNET_TESTNET_CHAIN_ID: u128 = 0x534e5f5345504f4c4941;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProofsData {
    pub chain_proofs: Vec<ChainProofs>,
    pub state_proofs: StateProofs,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPDryRunInput {
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
    pub injected_state: InjectedState,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPInput {
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
    pub injected_state: InjectedState,
    pub chain_proofs: Vec<ChainProofs>,
    pub state_proofs: StateProofs,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct InjectedState(pub HashMap<Felt252, Felt252>);

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ChainProofs {
    EthereumMainnet(evm::Proofs),
    EthereumSepolia(evm::Proofs),
    OptimismMainnet(evm::Proofs),
    OptimismSepolia(evm::Proofs),
    StarknetMainnet(starknet::Proofs),
    StarknetSepolia(starknet::Proofs),
}

impl ChainProofs {
    pub fn chain_id(&self) -> u128 {
        match self {
            ChainProofs::EthereumMainnet(_) => 0x1,
            ChainProofs::EthereumSepolia(_) => 0xaa36a7,
            ChainProofs::OptimismMainnet(_) => 0xa,
            ChainProofs::OptimismSepolia(_) => 0xaa37dc,
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
    OptimismMainnet,
    OptimismSepolia,
}

impl fmt::Display for ChainIds {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ChainIds::EthereumMainnet => write!(f, "ethereum-mainnet"),
            ChainIds::EthereumSepolia => write!(f, "ethereum-sepolia"),
            ChainIds::StarknetMainnet => write!(f, "starknet-mainnet"),
            ChainIds::StarknetSepolia => write!(f, "starknet-sepolia"),
            ChainIds::OptimismMainnet => write!(f, "optimism-mainnet"),
            ChainIds::OptimismSepolia => write!(f, "optimism-sepolia"),
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
            "optimism-mainnet" | "optimism_mainnet" | "optimismmainnet" => Ok(Self::OptimismMainnet),
            "optimism-sepolia" | "optimism_sepolia" | "optimismsepolia" => Ok(Self::OptimismSepolia),
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
            OPTIMISM_MAINNET_CHAIN_ID => Some(Self::OptimismMainnet),
            OPTIMISM_TESTNET_CHAIN_ID => Some(Self::OptimismSepolia),
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
    pub task_hash_low: Felt252,
    pub task_hash_high: Felt252,
    pub output_tree_root_low: Felt252,
    pub output_tree_root_high: Felt252,
}

impl FromIterator<Felt252> for HDPDryRunOutput {
    fn from_iter<T: IntoIterator<Item = Felt252>>(iter: T) -> Self {
        let mut i = iter.into_iter();
        let task_hash_low = i.next().unwrap();
        let task_hash_high = i.next().unwrap();
        let output_tree_root_low = i.next().unwrap();
        let output_tree_root_high = i.next().unwrap();

        Self {
            task_hash_low,
            task_hash_high,
            output_tree_root_low,
            output_tree_root_high,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "hash", rename_all = "lowercase")]
pub enum MmrMetaOutput {
    // We map those 4 felt words (id, size, chain_id, root) into this Poseidon variant.
    Poseidon {
        id: Felt252,
        size: Felt252,
        chain_id: Felt252,
        root: Felt252,
    },
    // We map those 5 felt words (id, size, chain_id, root_low, root_high) into this Poseidon variant.
    Keccak {
        id: Felt252,
        size: Felt252,
        chain_id: Felt252,
        root_low: Felt252,
        root_high: Felt252,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPOutput {
    pub task_hash_low: Felt252,
    pub task_hash_high: Felt252,
    pub output_tree_root_low: Felt252,
    pub output_tree_root_high: Felt252,
    pub mmr_metas: Vec<MmrMetaOutput>,
}

impl FromIterator<Felt252> for HDPOutput {
    fn from_iter<T: IntoIterator<Item = Felt252>>(iter: T) -> Self {
        let mut i = iter.into_iter();

        // Fixed 4 words
        let task_hash_low = i.next().unwrap();
        let task_hash_high = i.next().unwrap();
        let output_tree_root_low = i.next().unwrap();
        let output_tree_root_high = i.next().unwrap();

        // New mixed-layout header: [poseidon_len, keccak_len]
        let poseidon_len_f = i.next().unwrap();
        let keccak_len_f = i.next().unwrap();

        // Convert Felt252 -> usize by reading the last 8 bytes (big-endian)
        let felt_to_usize = |f: &Felt252| -> usize {
            let bytes = f.to_bytes_be();
            let mut buf = [0u8; 8];
            buf.copy_from_slice(&bytes[24..32]);
            u64::from_be_bytes(buf) as usize
        };
        let poseidon_len = felt_to_usize(&poseidon_len_f);
        let keccak_len = felt_to_usize(&keccak_len_f);

        // Poseidon section: poseidon_len * 4 felts
        let mut mmr_metas = Vec::<MmrMetaOutput>::with_capacity(poseidon_len + keccak_len);
        for _ in 0..poseidon_len {
            let [id, size, chain_id, root] = i.next_chunk::<4>().expect("missing poseidon mmr_meta words");
            mmr_metas.push(MmrMetaOutput::Poseidon { id, size, chain_id, root });
        }

        // Keccak section: keccak_len * 5 felts (id, size, chain_id, root_low, root_high)
        for _ in 0..keccak_len {
            let [id, size, chain_id, root_low, root_high] = i.next_chunk::<5>().expect("missing keccak mmr_meta words");
            mmr_metas.push(MmrMetaOutput::Keccak {
                id,
                size,
                chain_id,
                root_low,
                root_high,
            });
        }

        Self {
            task_hash_low,
            task_hash_high,
            output_tree_root_low,
            output_tree_root_high,
            mmr_metas,
        }
    }
}

impl HDPOutput {
    pub fn to_felt_vec(&self) -> Vec<Felt252> {
        let mut felt_vec = vec![
            self.task_hash_low,
            self.task_hash_high,
            self.output_tree_root_low,
            self.output_tree_root_high,
        ];

        // Counts
        let poseidon_len = self
            .mmr_metas
            .iter()
            .filter(|m| matches!(m, MmrMetaOutput::Poseidon { .. }))
            .count();
        let keccak_len = self.mmr_metas.iter().filter(|m| matches!(m, MmrMetaOutput::Keccak { .. })).count();
        felt_vec.push(Felt252::from(poseidon_len));
        felt_vec.push(Felt252::from(keccak_len));

        // Poseidon section
        self.mmr_metas.iter().for_each(|mmr_meta| {
            if let MmrMetaOutput::Poseidon { id, size, chain_id, root } = mmr_meta {
                felt_vec.extend([*id, *size, *chain_id, *root]);
            }
        });

        // Keccak section
        self.mmr_metas.iter().for_each(|mmr_meta| {
            if let MmrMetaOutput::Keccak {
                id,
                size,
                chain_id,
                root_low,
                root_high,
            } = mmr_meta
            {
                felt_vec.extend([*id, *size, *chain_id, *root_low, *root_high]);
            }
        });

        felt_vec
    }
}
