#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

pub mod models;

use std::env;

use models::{accumulators, IndexerError};
use reqwest::{Client, Url};
use types::RPC_URL_HERODOTUS_INDEXER_GROWER;

#[derive(Clone)]
pub struct Indexer {
    client: Client,
}

impl Default for Indexer {
    fn default() -> Self {
        Self::new()
    }
}

impl Indexer {
    pub fn new() -> Self {
        Self { client: Client::new() }
    }

    /// Fetch MMR and headers proof from Herodotus Indexer
    pub async fn get_headers_proof(
        &self,
        query: accumulators::IndexerQuery,
    ) -> Result<accumulators::IndexerHeadersProofResponse, IndexerError> {
        // Parse base URL from environment variable
        let base_url = Url::parse(&env::var(RPC_URL_HERODOTUS_INDEXER_GROWER).unwrap()).unwrap();

        let response = self
            .client
            .get(base_url.join("/accumulator/proofs").unwrap())
            .query(&query)
            .send()
            .await
            .map_err(IndexerError::ReqwestError)?;

        if response.status().is_success() {
            let parsed_mmr: accumulators::MMRResponse =
                serde_json::from_value(response.json().await.map_err(IndexerError::ReqwestError)?).map_err(IndexerError::SerdeJsonError)?;

            if parsed_mmr.data.is_empty() {
                Err(IndexerError::ValidationError("No MMR found".to_string()))
            } else if parsed_mmr.data.len() > 1 {
                Err(IndexerError::ValidationError("MMR length should be 1".to_string()))
            } else {
                let mmr_data = parsed_mmr.data[0].clone();
                if mmr_data.proofs.len() as usize != (query.to_block_number_inclusive - query.from_block_number_inclusive + 1) as usize {
                    Err(IndexerError::ValidationError(
                        "Indexer didn't return the correct number of headers that were requested".to_string(),
                    ))
                } else {
                    Ok(accumulators::IndexerHeadersProofResponse::new(mmr_data))
                }
            }
        } else {
            Err(IndexerError::GetHeadersProofError(
                response.text().await.map_err(IndexerError::ReqwestError)?,
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_headers_proof() {
        let response = Indexer::default()
            .get_headers_proof(accumulators::IndexerQuery::new(11155111, 5000000, 5000000))
            .await
            .unwrap();
        assert_eq!(response.headers.len(), 1);
    }

    #[tokio::test]
    async fn test_get_headers_proof_multiple_blocks() {
        let response = Indexer::default()
            .get_headers_proof(accumulators::IndexerQuery::new(11155111, 5800000, 5800010))
            .await
            .unwrap();
        assert_eq!(response.headers.len(), 11);
    }
}
