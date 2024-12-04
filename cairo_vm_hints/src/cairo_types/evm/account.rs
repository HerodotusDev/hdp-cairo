use crate::cairo_types::structs::Uint256;
use alloy::{consensus::Account, primitives::keccak256, rpc::types::EIP1186AccountProofResponse};
use alloy_rlp::{Decodable, Encodable};

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
}

impl From<EIP1186AccountProofResponse> for CairoAccount {
    fn from(value: EIP1186AccountProofResponse) -> Self {
        Self(Account {
            nonce: value.nonce,
            balance: value.balance,
            storage_root: value.storage_hash,
            code_hash: value.code_hash,
        })
    }
}
