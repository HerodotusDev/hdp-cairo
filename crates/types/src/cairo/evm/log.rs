use alloy::{
    consensus::{Receipt, ReceiptWithBloom, TxReceipt},
    primitives::keccak256,
    rpc::types::Log,
};
use alloy_rlp::{Decodable, Encodable};
use cairo_vm::Felt252;
use strum_macros::FromRepr;

use crate::cairo::{evm::error::CairoEvmError, structs::Uint256};

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Address = 0,
    Topic0 = 1,
    Topic1 = 2,
    Topic2 = 3,
    Topic3 = 4,
    Topic4 = 5,
    Data = 6,
}

#[derive(Debug)]
pub struct CairoReceiptWithBloom(ReceiptWithBloom);

impl CairoReceiptWithBloom {
    pub fn new(value: ReceiptWithBloom) -> Self {
        Self(value)
    }

    pub fn hash(&self) -> Uint256 {
        keccak256(self.rlp_encode()).into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn try_rlp_decode(mut rlp: &[u8]) -> Result<Self, CairoEvmError> {
        <ReceiptWithBloom>::decode(&mut rlp)
            .map(Self)
            .map_err(|e| CairoEvmError::RlpDecode {
                what: "evm::log/receipt_with_bloom",
                err: e.to_string(),
            })
    }

    pub fn handle(&self, function_id: FunctionId, log_index: usize) -> Result<Vec<Felt252>, CairoEvmError> {
        let logs = self.0.logs();
        let log = logs.get(log_index).ok_or(CairoEvmError::IndexOutOfBounds {
            what: "evm::log",
            index_name: "log_index",
            index: log_index,
            len: logs.len(),
        })?;

        let topic_index = match function_id {
            FunctionId::Topic0 => Some(0usize),
            FunctionId::Topic1 => Some(1usize),
            FunctionId::Topic2 => Some(2usize),
            FunctionId::Topic3 => Some(3usize),
            FunctionId::Topic4 => Some(4usize),
            _ => None,
        };

        if let Some(topic_index) = topic_index {
            let topics = log.data.topics();
            let topic = topics.get(topic_index).ok_or(CairoEvmError::IndexOutOfBounds {
                what: "evm::log",
                index_name: "topic_index",
                index: topic_index,
                len: topics.len(),
            })?;
            return Ok(<Uint256 as Into<[Felt252; 2]>>::into((*topic).into()).to_vec());
        }

        Ok(match function_id {
            FunctionId::Address => <Uint256 as Into<[Felt252; 2]>>::into(log.address.into()).to_vec(),
            FunctionId::Data => log
                .data
                .data
                .chunks((u128::BITS / 8) as usize)
                .map(Felt252::from_bytes_be_slice)
                .collect(),
            // Already handled above.
            FunctionId::Topic0 | FunctionId::Topic1 | FunctionId::Topic2 | FunctionId::Topic3 | FunctionId::Topic4 => {
                return Err(CairoEvmError::InternalInvariant {
                    what: "evm::log",
                    info: "topic branch should have returned earlier",
                });
            }
        })
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
