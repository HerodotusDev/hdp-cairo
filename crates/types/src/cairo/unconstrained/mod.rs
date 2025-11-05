use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};

pub mod bytecode;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum UnconstrainedStateValue {
    Bytecode(Bytes),
}
