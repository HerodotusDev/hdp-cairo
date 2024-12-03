use alloy::{
    primitives::{Address, BlockNumber, B256},
    rpc::types::{Block, EIP1186AccountProofResponse, Receipt, Transaction},
    transports::{RpcError, TransportErrorKind},
};

pub trait EVMProviderTrait {
    async fn get_account(&self, hash: Address, block_number: BlockNumber) -> Result<EIP1186AccountProofResponse, RpcError<TransportErrorKind>>;
    async fn get_block(&self, block_number: BlockNumber) -> Result<Block, RpcError<TransportErrorKind>>;
    async fn get_receipt(&self, hash: B256) -> Result<Receipt, RpcError<TransportErrorKind>>;
    async fn get_transaction(&self, hash: B256) -> Result<Transaction, RpcError<TransportErrorKind>>;
}
