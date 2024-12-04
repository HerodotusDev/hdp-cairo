use crate::cairo_types::structs::Uint256;
use alloy::primitives::{keccak256, StorageValue};
use alloy_rlp::{Decodable, Encodable};

pub struct CairoStorage(StorageValue);

impl CairoStorage {
    pub fn new(value: StorageValue) -> Self {
        Self(value)
    }

    pub fn get_storage(&self) -> Uint256 {
        self.0.into()
    }

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    // TODO missing impl

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        Self(<StorageValue>::decode(&mut rlp).unwrap())
    }
}

impl From<StorageValue> for CairoStorage {
    fn from(value: StorageValue) -> Self {
        Self(value)
    }
}
