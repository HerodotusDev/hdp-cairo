use alloy::{
    consensus::{transaction::TxEnvelope, TxType},
    rpc::types::Transaction,
};
use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

use crate::cairo::structs::Uint256;

#[derive(FromRepr, Debug, PartialEq, Eq)]
pub enum FunctionId {
    Nonce = 0,
    GasPrice = 1,
    GasLimit = 2,
    Receiver = 3,
    Value = 4,
    Data = 5,
    V = 6,
    R = 7,
    S = 8,
    ChainId = 9,
    AccessList = 10,
    MaxFeePerGas = 11,
    MaxPriorityFeePerGas = 12,
    MaxFeePerBlobGas = 13,
    BlobVersionedHashes = 14,
    TxType = 15,
    Sender = 16,
    Hash = 17,
}

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

    pub fn handle_legacy_tx(&self, function_id: FunctionId) -> Uint256 {
        let (fields, signature, _) = self.0.as_legacy().unwrap().clone().into_parts();

        match function_id {
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasPrice => fields.gas_price.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => (*fields.to.to().unwrap()).into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self.0.recover_signer().unwrap().into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            FunctionId::Data => panic!("Unsupported field `Data`"),
            _ => panic!("Unexpected tx field"),
        }
    }

    pub fn handle_eip_155_tx(&self, function_id: FunctionId) -> Uint256 {
        if function_id == FunctionId::ChainId {
            self.0.as_legacy().unwrap().tx().chain_id.unwrap().into()
        } else {
            self.handle_legacy_tx(function_id)
        }
    }

    pub fn handle_eip_2930_tx(&self, function_id: FunctionId) -> Uint256 {
        let (fields, signature, _) = self.0.as_eip2930().unwrap().clone().into_parts();

        match function_id {
            FunctionId::ChainId => fields.chain_id.into(),
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasPrice => fields.gas_price.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => (*fields.to.to().unwrap()).into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self.0.recover_signer().unwrap().into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            FunctionId::AccessList => panic!("Unsupported field `AccessList`"),
            FunctionId::Data => panic!("Unsupported field `Data`"),
            _ => panic!("Unexpected tx field"),
        }
    }

    pub fn handle_eip_1559_tx(&self, function_id: FunctionId) -> Uint256 {
        let (fields, signature, _) = self.0.as_eip1559().unwrap().clone().into_parts();

        match function_id {
            FunctionId::ChainId => fields.chain_id.into(),
            FunctionId::MaxPriorityFeePerGas => fields.max_priority_fee_per_gas.into(),
            FunctionId::MaxFeePerGas => fields.max_fee_per_gas.into(),
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => (*fields.to.to().unwrap()).into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self.0.recover_signer().unwrap().into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            FunctionId::AccessList => panic!("Unsupported field `AccessList`"),
            FunctionId::Data => panic!("Unsupported field `Data`"),
            _ => panic!("Unexpected tx field"),
        }
    }

    pub fn handle_eip_4844_tx(&self, function_id: FunctionId) -> Uint256 {
        let (fields, signature, _) = self.0.as_eip4844().unwrap().clone().into_parts();

        match function_id {
            FunctionId::ChainId => fields.tx().chain_id.into(),
            FunctionId::MaxPriorityFeePerGas => fields.tx().max_priority_fee_per_gas.into(),
            FunctionId::MaxFeePerGas => fields.tx().max_fee_per_gas.into(),
            FunctionId::MaxFeePerBlobGas => fields.tx().max_fee_per_blob_gas.into(),
            FunctionId::Nonce => fields.tx().nonce.into(),
            FunctionId::GasLimit => fields.tx().gas_limit.into(),
            FunctionId::Receiver => fields.tx().to.into(),
            FunctionId::Value => fields.tx().value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self.0.recover_signer().unwrap().into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            FunctionId::BlobVersionedHashes => panic!("Unsupported field `BlobVersionedHashes`"),
            FunctionId::AccessList => panic!("Unsupported field `AccessList`"),
            FunctionId::Data => panic!("Unsupported field `Data`"),
            _ => panic!("Unexpected tx field"),
        }
    }

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match self.0.tx_type() {
            TxType::Legacy => {
                if self.0.is_replay_protected() {
                    self.handle_eip_155_tx(function_id)
                } else {
                    self.handle_legacy_tx(function_id)
                }
            }
            TxType::Eip2930 => self.handle_eip_2930_tx(function_id),
            TxType::Eip1559 => self.handle_eip_1559_tx(function_id),
            TxType::Eip4844 => self.handle_eip_4844_tx(function_id),
            TxType::Eip7702 => panic!("Unsupported tx type"),
        }
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

impl From<Transaction> for CairoTransaction {
    fn from(value: Transaction) -> Self {
        Self(value.into_inner())
    }
}
