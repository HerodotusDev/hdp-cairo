use alloy::{consensus::Account, primitives::keccak256};
use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

use crate::cairo::structs::Uint256;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Nonce = 0,
    Balance = 1,
    StateRoot = 2,
    CodeHash = 3,
}

pub struct CairoAccount(Account);

impl CairoAccount {
    pub fn new(value: Account) -> Self {
        Self(value)
    }

    pub fn nonce(&self) -> Uint256 {
        self.0.nonce.into()
    }

    pub fn balance(&self) -> Uint256 {
        self.0.balance.into()
    }

    pub fn storage_hash(&self) -> Uint256 {
        self.0.storage_root.into()
    }

    pub fn code_hash(&self) -> Uint256 {
        self.0.code_hash.into()
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
        Self(<Account>::decode(&mut rlp).unwrap())
    }

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match function_id {
            FunctionId::Nonce => self.nonce(),
            FunctionId::Balance => self.balance(),
            FunctionId::StateRoot => self.storage_hash(),
            FunctionId::CodeHash => self.code_hash(),
        }
    }
}

impl From<Account> for CairoAccount {
    fn from(value: Account) -> Self {
        Self(value)
    }
}
