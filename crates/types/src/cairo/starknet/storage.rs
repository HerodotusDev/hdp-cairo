use strum_macros::FromRepr;

use crate::cairo::structs::Felt;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Storage = 0,
}

pub struct CairoStorage(Felt);

impl CairoStorage {
    pub fn new(value: Felt) -> Self {
        Self(value)
    }

    pub fn storage(&self) -> Felt {
        self.0.clone()
    }

    pub fn handler(&self, function_id: FunctionId) -> Felt {
        match function_id {
            FunctionId::Storage => self.storage(),
        }
    }
}

impl From<Felt> for CairoStorage {
    fn from(value: Felt) -> Self {
        Self(value)
    }
}
