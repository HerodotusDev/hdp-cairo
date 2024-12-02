use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::Felt252;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Param {
    pub visibility: Visibility,
    pub value: Felt252,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Visibility {
    Public,
    Private,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct HDPDryRunInput {
    pub params: Vec<Param>,
    pub compiled_class: CasmContractClass,
}
