use crate::cairo::structs::Uint256;
use alloy::{
    consensus::Header,
    primitives::{keccak256, Bloom, Bytes},
};
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

    pub fn coinbase(&self) -> Uint256 {
        self.0.beneficiary.into()
    }

    pub fn state_root(&self) -> Uint256 {
        self.0.state_root.into()
    }

    pub fn transactions_root(&self) -> Uint256 {
        self.0.transactions_root.into()
    }

    pub fn receipts_root(&self) -> Uint256 {
        self.0.receipts_root.into()
    }

    pub fn bloom(&self) -> &Bloom {
        &self.0.logs_bloom
    }

    pub fn difficulty(&self) -> Uint256 {
        self.0.difficulty.into()
    }

    pub fn number(&self) -> Uint256 {
        self.0.number.into()
    }

    pub fn gas_limit(&self) -> Uint256 {
        self.0.gas_limit.into()
    }

    pub fn gas_used(&self) -> Uint256 {
        self.0.gas_used.into()
    }

    pub fn timestamp(&self) -> Uint256 {
        self.0.timestamp.into()
    }

    pub fn extra_data(&self) -> &Bytes {
        &self.0.extra_data
    }

    pub fn mix_hash(&self) -> Uint256 {
        self.0.mix_hash.into()
    }

    pub fn nonce(&self) -> Uint256 {
        self.0.nonce.into()
    }

    pub fn base_fee_per_gas(&self) -> Option<Uint256> {
        self.0.base_fee_per_gas.map(|f| f.into())
    }

    pub fn withdrawals_root(&self) -> Option<Uint256> {
        self.0.withdrawals_root.map(|f| f.into())
    }

    pub fn blob_gas_used(&self) -> Option<Uint256> {
        self.0.blob_gas_used.map(|f| f.into())
    }

    pub fn excess_blob_gas(&self) -> Option<Uint256> {
        self.0.excess_blob_gas.map(|f| f.into())
    }

    pub fn parent_beacon_block_root(&self) -> Option<Uint256> {
        self.0.parent_beacon_block_root.map(|f| f.into())
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
        Self(<Header>::decode(&mut rlp).unwrap())
    }

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match function_id {
            FunctionId::Parent => self.parent(),
            FunctionId::Uncle => self.uncle(),
            FunctionId::Coinbase => self.coinbase(),
            FunctionId::StateRoot => self.state_root(),
            FunctionId::ReceiptRoot => self.receipts_root(),
            FunctionId::TransactionRoot => self.transactions_root(),
            FunctionId::Difficulty => self.difficulty(),
            FunctionId::Number => self.number(),
            FunctionId::GasLimit => self.gas_limit(),
            FunctionId::GasUsed => self.gas_used(),
            FunctionId::Timestamp => self.timestamp(),
            FunctionId::MixHash => self.mix_hash(),
            FunctionId::Nonce => self.nonce(),
            _ => Uint256::default(),
        }
    }
}

impl From<Header> for CairoHeader {
    fn from(value: Header) -> Self {
        Self(value)
    }
}
