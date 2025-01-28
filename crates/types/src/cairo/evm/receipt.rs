use alloy::{
    consensus::{Eip658Value, Receipt, ReceiptWithBloom},
    primitives::keccak256,
    rpc::types::Log,
};
use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

use crate::cairo::structs::Uint256;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Status = 0,
    CumulativeGasUsed = 1,
    Bloom = 2,
    Logs = 3,
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

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match function_id {
            FunctionId::Status => self.status(),
            FunctionId::CumulativeGasUsed => self.cumulative_gas_used(),
            FunctionId::Bloom => panic!("Bloom function id is not supported"),
            FunctionId::Logs => panic!("Logs function id is not supported"),
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
