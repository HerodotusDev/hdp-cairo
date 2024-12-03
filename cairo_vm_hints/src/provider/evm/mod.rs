use alloy::{
    hex::ToHexExt,
    primitives::{Address, BlockNumber, B256},
    rpc::{
        client::{ClientBuilder, ReqwestClient},
        types::{Block, EIP1186AccountProofResponse, Receipt, Transaction},
    },
    transports::{http::reqwest::Url, RpcError, TransportErrorKind},
};
use serde_json::json;
use traits::EVMProviderTrait;

pub mod traits;

pub struct EVMProvider {
    client: ReqwestClient,
}

impl EVMProvider {
    pub fn new(url: Url) -> Self {
        Self {
            client: ClientBuilder::default().http(url),
        }
    }
}

impl EVMProviderTrait for EVMProvider {
    async fn get_account(&self, address: Address, block_number: BlockNumber) -> Result<EIP1186AccountProofResponse, RpcError<TransportErrorKind>> {
        let mut batch = self.client.new_batch();
        let fut = batch.add_call(
            "eth_getProof",
            &json!([
                address.encode_hex_with_prefix(),
                [],
                format!("0x{}", block_number.to_be_bytes().encode_hex().trim_start_matches('0'))
            ]),
        )?;
        batch.send().await?;
        fut.await
    }
    async fn get_block(&self, block_number: BlockNumber) -> Result<Block, RpcError<TransportErrorKind>> {
        let mut batch = self.client.new_batch();
        let fut = batch.add_call(
            "eth_getBlockByNumber",
            &json!([format!("0x{}", block_number.to_be_bytes().encode_hex().trim_start_matches('0')), false]),
        )?;
        batch.send().await?;
        fut.await
    }
    async fn get_receipt(&self, hash: B256) -> Result<Receipt, RpcError<TransportErrorKind>> {
        let mut batch = self.client.new_batch();
        let fut = batch.add_call("eth_getTransactionReceipt", &json!([hash.encode_hex_with_prefix()]))?;
        batch.send().await?;
        fut.await
    }
    async fn get_transaction(&self, hash: B256) -> Result<Transaction, RpcError<TransportErrorKind>> {
        let mut batch = self.client.new_batch();
        let fut = batch.add_call("eth_getTransactionByHash", &json!([hash.encode_hex_with_prefix()]))?;
        batch.send().await?;
        fut.await
    }
}

#[cfg(test)]
mod tests {
    use super::{EVMProvider, EVMProviderTrait};
    use alloy::{
        hex::FromHex,
        primitives::{Address, B256},
    };

    const RPC_URL: &str = "https://eth-mainnet.g.alchemy.com/v2/u_DzVM70jRTQByTwvcdhjvgVRQE0dVnf";

    #[tokio::test]
    async fn test_get_account() {
        let client = EVMProvider::new(RPC_URL.parse().unwrap());
        client
            .get_account(Address::from_hex("F585A4aE338bC165D96E8126e8BBcAcAE725d79E").unwrap(), 20992954)
            .await
            .unwrap();
    }

    #[tokio::test]
    async fn test_get_block() {
        let client = EVMProvider::new(RPC_URL.parse().unwrap());
        client.get_block(20992954).await.unwrap();
    }

    #[tokio::test]
    async fn test_get_recipt() {
        let client = EVMProvider::new(RPC_URL.parse().unwrap());
        client
            .get_receipt(B256::from_hex("237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51").unwrap())
            .await
            .unwrap();
    }

    #[tokio::test]
    async fn test_get_transaction() {
        let client = EVMProvider::new(RPC_URL.parse().unwrap());
        client
            .get_transaction(B256::from_hex("237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51").unwrap())
            .await
            .unwrap();
    }
}
