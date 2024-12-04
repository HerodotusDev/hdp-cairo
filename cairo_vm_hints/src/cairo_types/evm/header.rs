use crate::cairo_types::structs::Uint256;
use alloy::{consensus::Header, primitives::keccak256};
use alloy_rlp::{Decodable, Encodable};

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
}

impl From<Header> for CairoHeader {
    fn from(value: Header) -> Self {
        Self(value)
    }
}
