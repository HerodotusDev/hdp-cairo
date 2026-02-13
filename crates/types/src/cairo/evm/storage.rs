use alloy::primitives::{keccak256, StorageValue};
use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

use crate::cairo::{evm::error::CairoEvmError, structs::Uint256};

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

    pub fn try_rlp_decode(mut rlp: &[u8]) -> Result<Self, CairoEvmError> {
        <StorageValue>::decode(&mut rlp).map(Self).map_err(|e| CairoEvmError::RlpDecode {
            what: "evm::storage",
            err: e.to_string(),
        })
    }

    pub fn handle(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        Ok(match function_id {
            FunctionId::Storage => self.storage(),
        })
    }
}

impl From<StorageValue> for CairoStorage {
    fn from(value: StorageValue) -> Self {
        Self(value)
    }
}
