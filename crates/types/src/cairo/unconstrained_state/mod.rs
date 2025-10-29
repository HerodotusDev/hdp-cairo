use strum_macros::FromRepr;

use crate::cairo::new_syscalls::CairoVec;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Bytecode = 0,
}

// TODO: @beeinger - not sure how it's used???
pub struct UnconstrainedState(CairoVec);

impl UnconstrainedState {
    pub fn new(value: CairoVec) -> Self {
        Self(value)
    }

    pub fn bytecode(&self) -> CairoVec {
        self.0.clone()
    }

    pub fn handler(&self, function_id: FunctionId) -> CairoVec {
        match function_id {
            FunctionId::Bytecode => self.bytecode(),
        }
    }
}
