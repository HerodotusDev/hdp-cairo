use std::collections::HashMap;

use alloy::{hex::FromHexError, primitives::Bytes};
use indexer::{models::accumulators, Indexer};
use types::{
    proofs::{injected_state::Action, mmr::MmrMeta},
    Felt252,
};

use crate::FetcherError;

pub mod evm;
pub mod starknet;
pub mod unconstrained_state;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct FlattenedKey {
    pub chain_id: u128,
    pub block_number: u64,
}

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub evm: evm::ProofKeys,
    pub starknet: starknet::ProofKeys,
    pub injected_state: HashMap<Felt252, Vec<Action>>,
    pub unconstrained_state: unconstrained_state::ProofKeys,
}

impl ProofKeys {
    fn normalize_hex(input: &str) -> String {
        let hex_str = input.trim_start_matches("0x");
        format!("{:0>width$}", hex_str, width = hex_str.len().div_ceil(2) * 2)
    }

    pub async fn fetch_mmr_proof(
        deployed_on_chain_id: u128,
        accumulates_chain_id: u128,
        block_number: u64,
    ) -> Result<(accumulators::MMRProof, MmrMeta), FetcherError> {
        let provider = Indexer::default();

        // Fetch proof response
        let response = provider
            .get_headers_proof(accumulators::IndexerQuery::new(
                deployed_on_chain_id,
                accumulates_chain_id,
                block_number,
                block_number,
            ))
            .await?;

        // Extract MMR metadata
        let meta = MmrMeta {
            id: Self::normalize_hex(&response.mmr_meta.mmr_id).parse()?,
            size: response.mmr_meta.mmr_size,
            root: Self::normalize_hex(&response.mmr_meta.mmr_root).parse()?,
            chain_id: accumulates_chain_id,
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
