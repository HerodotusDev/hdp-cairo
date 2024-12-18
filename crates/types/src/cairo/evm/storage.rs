use crate::cairo::structs::Uint256;
use alloy::primitives::{keccak256, StorageValue};
use alloy_rlp::{Decodable, Encodable};
use cairo_vm::Felt252;
use strum_macros::FromRepr;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Storage = 0,
}

pub struct CairoStorage(StorageValue);

impl CairoStorage {
    pub fn new(value: StorageValue) -> Self {
        Self(value)
    }

    pub fn storage(&self) -> Uint256 {
        self.0.into()
    }

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        Self(<StorageValue>::decode(&mut rlp).unwrap())
    }

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match function_id {
            FunctionId::Storage => self.storage(),
        }
    }
}

impl From<StorageValue> for CairoStorage {
    fn from(value: StorageValue) -> Self {
        Self(value)
    }
}
