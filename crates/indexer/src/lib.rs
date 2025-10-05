#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

pub mod models;

use std::env;

use cairo_vm::Felt252;
use models::{accumulators, blocks, IndexerError};
use reqwest::{Client, Url};
use types::RPC_URL_HERODOTUS_INDEXER;

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
    pub async fn get_headers_proof(&self, query: accumulators::IndexerQuery) -> Result<accumulators::IndexerProofResponse, IndexerError> {
        // Parse base URL from environment variable
        let base_url = Url::parse(&env::var(RPC_URL_HERODOTUS_INDEXER).unwrap()).unwrap();

        let response = self
            .client
            .get(base_url.join("/accumulators/proofs").unwrap())
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
                    Ok(accumulators::IndexerProofResponse::new(mmr_data))
                }
            }
        } else {
            Err(IndexerError::GetHeadersProofError(
                response.text().await.map_err(IndexerError::ReqwestError)?,
            ))
        }
    }

    /// Fetch MMR and headers proof from Herodotus Indexer
    pub async fn get_blocks(&self, query: blocks::IndexerQuery) -> Result<blocks::IndexerBlockResponse, IndexerError> {
        // Parse base URL from environment variable
        let base_url = Url::parse(&env::var(RPC_URL_HERODOTUS_INDEXER).unwrap()).unwrap();

        let response = self
            .client
            .get(base_url.join("/blocks").unwrap())
            .query(&query)
            .send()
            .await
            .map_err(IndexerError::ReqwestError)?;

        if response.status().is_success() {
            let parsed_mmr: blocks::BlocksResponse =
                serde_json::from_value(response.json().await.map_err(IndexerError::ReqwestError)?).map_err(IndexerError::SerdeJsonError)?;

            let block = parsed_mmr.data.first().unwrap();

            match &block.block_header {
                models::BlockHeader::Fields(fields) => Ok(blocks::IndexerBlockResponse {
                    fields: fields.iter().map(|hex| Felt252::from_hex(hex).unwrap()).collect::<Vec<_>>(),
                }),
                _ => Err(IndexerError::ValidationError("Invalid block header return type".to_string())),
            }
        } else {
            Err(IndexerError::GetBlocksProofError(
                response.text().await.map_err(IndexerError::ReqwestError)?,
            ))
        }
    }

    /// Fetch accumulated ranges per (source_chain -> deployed_on_chain) and hashing function
    pub async fn get_all_ranges_accumulated_per_chain(
        &self,
    ) -> Result<models::ranges::RangesResponse, IndexerError> {
        // Parse base URL from environment variable
        let base_url = Url::parse(&env::var(RPC_URL_HERODOTUS_INDEXER).unwrap()).unwrap();

        let response = self
            .client
            .get(base_url.join("/backend/get-all-ranges-accumulated-per-chain").unwrap())
            .send()
            .await
            .map_err(IndexerError::ReqwestError)?;

        if response.status().is_success() {
            let parsed: models::ranges::RangesResponse =
                serde_json::from_value(response.json().await.map_err(IndexerError::ReqwestError)?)
                    .map_err(IndexerError::SerdeJsonError)?;
            Ok(parsed)
        } else {
            Err(IndexerError::GetRangesError(
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
        dotenvy::dotenv().ok();
        let response = Indexer::default()
            .get_headers_proof(accumulators::IndexerQuery::new(11155111, 11155111, 7692344, 7692344))
            .await
            .unwrap();
        assert_eq!(response.headers.len(), 1);
    }

    #[tokio::test]
    async fn test_get_headers_proof_multiple_blocks() {
        dotenvy::dotenv().ok();
        let response = Indexer::default()
            .get_headers_proof(accumulators::IndexerQuery::new(11155111, 11155111, 7692144, 7692344))
            .await
            .unwrap();
        assert_eq!(response.headers.len(), 201);
    }
}
