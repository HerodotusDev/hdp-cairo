use crate::structs::Uint256;
use alloy::{consensus::transaction::TxEnvelope, rpc::types::Transaction};
use alloy_rlp::{Decodable, Encodable};

pub struct CairoTransaction(TxEnvelope);

impl CairoTransaction {
    pub fn new(value: TxEnvelope) -> Self {
        Self(value)
    }

    pub fn hash(&self) -> Uint256 {
        self.0.tx_hash().to_owned().into()
    }

    pub fn signature_hash(&self) -> Uint256 {
        self.0.signature_hash().into()
    }

    // TODO missing impl

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        Self(<TxEnvelope>::decode(&mut rlp).unwrap())
    }
}

impl From<Transaction> for CairoTransaction {
    fn from(value: Transaction) -> Self {
        Self(value.inner)
    }
}
