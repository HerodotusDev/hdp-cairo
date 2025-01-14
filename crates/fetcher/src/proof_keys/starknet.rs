use std::{collections::HashSet, env};
use reqwest::Url;
use types::{keys, proofs::{starknet::GetProofOutput, HeaderMmrMeta}, STARKNET_RPC};

use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::starknet::header::Key>,
    pub storage_keys: HashSet<keys::starknet::storage::Key>,
}

impl ProofKeys {
    pub async fn fetch_storage_proof(key: &keys::starknet::storage::Key) -> Result<(HeaderMmrMeta, GetProofOutput), FetcherError> {
        let params = serde_json::json!([
            key.address,
            key.storage_slot,
            key.block_number
        ]);

        let response = reqwest::Client::new()
            .post(Url::parse(&env::var(STARKNET_RPC).unwrap()).unwrap())
            .json(&serde_json::json!({
                "jsonrpc": "2.0",
                "method": "starknet_getStorageAt",
                "params": params,
                "id": 1
            }))
            .send()
            .await?;

        let proof: GetProofOutput = response.json().await?;
        Ok((
            super::ProofKeys::fetch_header_proof(key.chain_id, key.block_number).await?,
            proof
        ))
    }
}
