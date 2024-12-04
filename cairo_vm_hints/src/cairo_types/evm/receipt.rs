use crate::cairo_types::structs::Uint256;
use alloy::{
    consensus::{ReceiptWithBloom, RlpEncodableReceipt, TxReceipt},
    primitives::keccak256,
};
use alloy_rlp::Decodable;

pub struct CairoReceiptWithBloom(ReceiptWithBloom);

impl CairoReceiptWithBloom {
    pub fn new(value: ReceiptWithBloom) -> Self {
        Self(value)
    }

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.0.receipt.rlp_encode_with_bloom(&self.0.bloom(), &mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        Self(<ReceiptWithBloom>::decode(&mut rlp).unwrap())
    }
}

impl From<ReceiptWithBloom> for CairoReceiptWithBloom {
    fn from(value: ReceiptWithBloom) -> Self {
        Self(value)
    }
}
