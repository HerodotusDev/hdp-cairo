use crate::cairo::structs::Uint256;
use alloy::{
    consensus::{Eip658Value, ReceiptWithBloom, TxReceipt},
    primitives::{keccak256, Log},
    rpc::types::{Receipt, TransactionReceipt},
};

use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Status = 0,
    Bloom = 1,
    CumulativeGasUsed = 2,
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

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(rlp: &[u8]) -> Self {
        Self(ReceiptWithBloom::decode(&mut &*rlp).unwrap())
    }

    pub fn handle(&self, function_id: FunctionId) -> Uint256 {
        match function_id {
            FunctionId::Status => self.status(),
            FunctionId::Bloom => Uint256::from(self.0.logs_bloom),
            FunctionId::CumulativeGasUsed => Uint256::from(self.0.receipt.cumulative_gas_used),
        }
    }
}

impl From<TransactionReceipt> for CairoReceiptWithBloom {
    fn from(receipt: TransactionReceipt) -> Self {
        let mut logs_vec = vec![];
        for log in receipt.inner.logs() {
            logs_vec.push(log.inner.clone());
        }
        Self(ReceiptWithBloom {
            logs_bloom: *receipt.inner.logs_bloom(),
            receipt: Receipt::<Log> {
                status: receipt.inner.status_or_post_state(),
                logs: logs_vec,
                cumulative_gas_used: receipt.inner.cumulative_gas_used(),
            },
        })
    }
}

impl From<ReceiptWithBloom> for CairoReceiptWithBloom {
    fn from(value: ReceiptWithBloom) -> Self {
        Self(value)
    }
}
