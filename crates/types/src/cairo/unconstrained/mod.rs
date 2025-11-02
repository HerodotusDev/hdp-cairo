use serde::{Deserialize, Serialize};

use crate::cairo::unconstrained::bytecode::BytecodeLeWords;

pub mod bytecode;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum UnconstrainedStateValue {
    Bytecode(BytecodeLeWords),
}
