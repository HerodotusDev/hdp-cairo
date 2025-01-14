use std::collections::HashSet;

use indexer::{types::IndexerQuery, Indexer};
use types::{keys, proofs::HeaderMmrMeta};

use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::starknet::header::Key>,
    pub storage_keys: HashSet<keys::starknet::storage::Key>,
}

impl ProofKeys {
    pub async fn fetch_header_proof(&self, key: &keys::starknet::header::Key) -> Result<HeaderMmrMeta, FetcherError> {
        let provider = Indexer::default();

        let response = provider
            .get_headers_proof(IndexerQuery::new(key.chain_id, key.block_number, key.block_number))
            .await?;

        unimplemented!()
    }
}
