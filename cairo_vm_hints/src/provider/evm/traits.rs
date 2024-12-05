use alloy::{
    primitives::{Address, BlockNumber, StorageKey, StorageValue, B256},
    rpc::types::{Block, EIP1186AccountProofResponse, Receipt, Transaction},
    transports::{RpcError, TransportErrorKind},
};

pub trait EVMProviderTrait {
    async fn get_account(&self, address: Address, block_number: BlockNumber) -> Result<EIP1186AccountProofResponse, RpcError<TransportErrorKind>>;
    async fn get_block(&self, block_number: BlockNumber) -> Result<Block, RpcError<TransportErrorKind>>;
    async fn get_storage(&self, address: Address, block_number: BlockNumber, key: StorageKey) -> Result<StorageValue, RpcError<TransportErrorKind>>;
    async fn get_transaction_receipt(&self, hash: B256) -> Result<Receipt, RpcError<TransportErrorKind>>;
    async fn get_transaction(&self, hash: B256) -> Result<Transaction, RpcError<TransportErrorKind>>;
}
