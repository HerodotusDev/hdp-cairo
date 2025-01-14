use cairo_vm::Felt252;
use strum_macros::FromRepr;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Storage = 0,
}

pub struct CairoStorage(Felt252);

impl CairoStorage {
    pub fn new(value: Felt252) -> Self {
        Self(value)
    }

    pub fn storage(&self) -> Felt252 {
        self.0
    }

    pub fn handler(&self, function_id: FunctionId) -> Felt252 {
        match function_id {
            FunctionId::Storage => self.storage(),
        }
    }
}

impl From<Felt252> for CairoStorage {
    fn from(value: Felt252) -> Self {
        Self(value)
    }
}
