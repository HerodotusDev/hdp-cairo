use crate::cairo_types::structs::Uint256;
use alloy::consensus::transaction::TxEnvelope;
use alloy::primitives::keccak256;
use alloy_rlp::{Decodable, Encodable};

pub struct CairoTransaction(TxEnvelope);

impl CairoTransaction {
    pub fn new(value: TxEnvelope) -> Self {
        Self(value)
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
        Self(<TxEnvelope>::decode(&mut rlp).unwrap())
    }
}

impl From<TxEnvelope> for CairoTransaction {
    fn from(value: TxEnvelope) -> Self {
        Self(value)
    }
}
