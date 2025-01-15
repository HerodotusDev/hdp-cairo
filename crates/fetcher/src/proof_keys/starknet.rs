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
        let response = reqwest::Client::new()
            .post(Url::parse(&env::var(STARKNET_RPC).unwrap()).unwrap())
            .json(&serde_json::json!({
                "jsonrpc": "2.0",
                "method": "pathfinder_getProof",
                "params": [
                    {"block_number": key.block_number},
                    key.address,
                    [key.storage_slot]
                ],
                "id": 1
            }))
            .send()
            .await?;
        
        let response_text = response.text().await?;

        let json_rpc_response: serde_json::Value = serde_json::from_str(&response_text)
            .map_err(|e| FetcherError::JsonDeserializationError(e.to_string()))?;
        
        let proof = serde_json::from_value::<GetProofOutput>(json_rpc_response["result"].clone())
            .map_err(|e| {
                println!("Deserialization error: {}", e);
                FetcherError::JsonDeserializationError(e.to_string())
            })?;

        Ok((
            super::ProofKeys::fetch_header_proof(key.chain_id, key.block_number).await?,
            proof
        ))
    }
}
