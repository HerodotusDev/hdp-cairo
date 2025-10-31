use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;

use crate::cairo::unconstrained_state::bytecode::BytecodeLeWords;

pub mod bytecode;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Bytecode = 0,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum UnconstrainedStateValue {
    Bytecode(BytecodeLeWords),
}

// TODO: @Okm165 - not sure how it's used???
pub struct UnconstrainedState(UnconstrainedStateValue);

impl UnconstrainedState {
    pub fn new(value: UnconstrainedStateValue) -> Self {
        Self(value)
    }

    pub fn bytecode(&self) -> BytecodeLeWords {
        match &self.0 {
            UnconstrainedStateValue::Bytecode(bytecode) => bytecode.clone(),
        }
    }

    pub fn handler(&self, function_id: FunctionId) -> UnconstrainedStateValue {
        match function_id {
            FunctionId::Bytecode => self.0.clone(),
        }
    }
}
