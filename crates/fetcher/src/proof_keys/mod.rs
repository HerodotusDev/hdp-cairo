use alloy::{hex::FromHexError, primitives::Bytes};
use indexer::{
    models::{IndexerQuery, MMRProof},
    Indexer,
};
use types::proofs::mmr::MmrMeta;

use crate::FetcherError;

pub mod evm;
pub mod starknet;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub evm: evm::ProofKeys,
    pub starknet: starknet::ProofKeys,
}

impl ProofKeys {
    fn normalize_hex(input: &str) -> String {
        let hex_str = input.trim_start_matches("0x");
        format!("{:0>width$}", hex_str, width = (hex_str.len() + 1) / 2 * 2)
    }

    pub async fn fetch_mmr_proof(chain_id: u128, block_number: u64) -> Result<(MMRProof, MmrMeta), FetcherError> {
        let provider = Indexer::default();

        // Fetch proof response
        let response = provider
            .get_headers_proof(IndexerQuery::new(chain_id, block_number, block_number))
            .await?;

        // Extract MMR metadata
        let meta = MmrMeta {
            id: u64::from_str_radix(&response.mmr_meta.mmr_id[2..], 16)?,
            size: response.mmr_meta.mmr_size,
            root: Self::normalize_hex(&response.mmr_meta.mmr_root).parse()?,
            peaks: response
                .mmr_meta
                .mmr_peaks
                .iter()
                .map(|peak| Self::normalize_hex(peak).parse())
                .collect::<Result<Vec<Bytes>, FromHexError>>()?,
        };

        let proof = response
            .headers
            .get(&block_number)
            .ok_or_else(|| FetcherError::InternalError("block not found".into()))?;

        Ok((proof.clone(), meta))
    }
}
