use crate::{cairo_types::structs::Uint256, syscall_handler::utils::SyscallExecutionError};
use alloy::{consensus::Header, primitives::keccak256};
use alloy_rlp::{Decodable, Encodable};
use cairo_vm::Felt252;
use strum_macros::FromRepr;

#[derive(FromRepr, Debug)]
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

    pub fn parent(&self) -> Uint256 {
        self.0.parent_hash.into()
    }

    pub fn uncle(&self) -> Uint256 {
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
            FunctionId::Parent => self.parent(),
            FunctionId::Uncle => self.uncle(),
            _ => Uint256::default(),
        }
    }
}

impl From<Header> for CairoHeader {
    fn from(value: Header) -> Self {
        Self(value)
    }
}

impl TryFrom<Felt252> for FunctionId {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        Self::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })
    }
}
