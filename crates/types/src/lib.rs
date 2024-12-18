pub mod cairo;
pub mod keys;
pub mod param;
pub mod proofs;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use param::Param;
use proofs::Proofs;
use serde::{Deserialize, Serialize};

pub const RPC: &str = "RPC";

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPDryRunInput {
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPInput {
    pub proofs: Vec<Proofs>,
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
}
