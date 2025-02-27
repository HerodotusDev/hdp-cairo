use alloy::{
    consensus::{Eip658Value, Receipt, ReceiptWithBloom, TxReceipt},
    primitives::keccak256,
    rpc::types::Log,
};
use alloy_rlp::{Decodable, Encodable};
use cairo_vm::Felt252;
use strum_macros::FromRepr;

use crate::cairo::structs::Uint256;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Status = 0,
    CumulativeGasUsed = 1,
    Bloom = 2,
    Address = 3,
    Topic0 = 3 + 1,
    Topic1 = 3 + 2,
    Topic2 = 3 + 3,
    Topic3 = 3 + 4,
    Topic4 = 3 + 5,
    Data = 3 + 6,
}

#[derive(Debug)]
pub struct CairoReceiptWithBloom(ReceiptWithBloom);

impl CairoReceiptWithBloom {
    pub fn new(value: ReceiptWithBloom) -> Self {
        Self(value)
    }

    pub fn status(&self) -> Uint256 {
        match self.0.receipt.status {
            Eip658Value::Eip658(status) => Uint256::from(status as u64),
            Eip658Value::PostState(hash) => Uint256::from(hash),
        }
    }

    pub fn cumulative_gas_used(&self) -> Uint256 {
        Uint256::from(self.0.receipt.cumulative_gas_used)
    }

    pub fn bloom(&self) -> Uint256 {
        Uint256::from(self.0.logs_bloom)
    }

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        Self(<ReceiptWithBloom>::decode(&mut rlp).unwrap())
    }

    pub fn handle(&self, function_id: FunctionId) -> Vec<Felt252> {
        match function_id {
            FunctionId::Status => <Uint256 as Into<[Felt252; 2]>>::into(self.status()).to_vec(),
            FunctionId::CumulativeGasUsed => <Uint256 as Into<[Felt252; 2]>>::into(self.cumulative_gas_used()).to_vec(),
            FunctionId::Bloom => <Uint256 as Into<[Felt252; 2]>>::into(self.bloom()).to_vec(),
            FunctionId::Address => <Uint256 as Into<[Felt252; 2]>>::into(self.0.logs().first().unwrap().address.into()).to_vec(),
            FunctionId::Topic0 => <Uint256 as Into<[Felt252; 2]>>::into(self.0.logs().first().unwrap().data.topics()[0].into()).to_vec(),
            FunctionId::Topic1 => <Uint256 as Into<[Felt252; 2]>>::into(self.0.logs().first().unwrap().data.topics()[1].into()).to_vec(),
            FunctionId::Topic2 => <Uint256 as Into<[Felt252; 2]>>::into(self.0.logs().first().unwrap().data.topics()[2].into()).to_vec(),
            FunctionId::Topic3 => <Uint256 as Into<[Felt252; 2]>>::into(self.0.logs().first().unwrap().data.topics()[3].into()).to_vec(),
            FunctionId::Topic4 => <Uint256 as Into<[Felt252; 2]>>::into(self.0.logs().first().unwrap().data.topics()[4].into()).to_vec(),
            FunctionId::Data => self
                .0
                .logs()
                .first()
                .unwrap()
                .data
                .data
                .chunks((u128::BITS / 8) as usize)
                .rev()
                .map(Felt252::from_bytes_be_slice)
                .collect(),
        }
    }
}

impl From<ReceiptWithBloom<Receipt<Log>>> for CairoReceiptWithBloom {
    fn from(receipt: ReceiptWithBloom<Receipt<Log>>) -> Self {
        Self(ReceiptWithBloom {
            logs_bloom: receipt.logs_bloom,
            receipt: Receipt {
                status: receipt.receipt.status,
                cumulative_gas_used: receipt.receipt.cumulative_gas_used,
                logs: receipt.receipt.logs.into_iter().map(|log| log.inner.clone()).collect(),
            },
        })
    }
}

impl From<ReceiptWithBloom> for CairoReceiptWithBloom {
    fn from(value: ReceiptWithBloom) -> Self {
        Self(value)
    }
}
