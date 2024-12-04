use crate::cairo_types::structs::Uint256;
use alloy::{consensus::Header, primitives::keccak256};
use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

#[derive(FromRepr)]
pub enum FunctionId {
    Parent = 0,
    Uncle = 1,
    Coinbase = 2,
    StateRoot = 3,
    TransactionRoot = 4,
    ReceiptRoot = 5,
    Bloom = 6,
    Difficulty = 7,
    Number = 8,
    GasLimit = 9,
    GasUsed = 10,
    Timestamp = 11,
    ExtraData = 12,
    MixHash = 13,
    Nonce = 14,
    BaseFeePerGas = 15,
    WithdrawalsRoot = 16,
    BlobGasUsed = 17,
    ExcessBlobGas = 18,
    ParentBeaconBlockRoot = 19,
}

pub struct CairoHeader(Header);

impl CairoHeader {
    pub fn new(value: Header) -> Self {
        Self(value)
    }

    pub fn get_parent(&self) -> Uint256 {
        self.0.parent_hash.into()
    }

    pub fn get_uncle(&self) -> Uint256 {
        self.0.ommers_hash.into()
    }

    // TODO missing impl

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        Self(<Header>::decode(&mut rlp).unwrap())
    }

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match function_id {
            FunctionId::Parent => self.get_parent(),
            FunctionId::Uncle => self.get_uncle(),
            _ => Uint256::default(),
        }
    }
}

impl From<Header> for CairoHeader {
    fn from(value: Header) -> Self {
        Self(value)
    }
}
