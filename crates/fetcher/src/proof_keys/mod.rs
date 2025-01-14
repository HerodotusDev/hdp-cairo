use alloy::{
    hex::FromHexError,
    primitives::Bytes,
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use indexer::{
    types::{BlockHeader, IndexerQuery},
    Indexer,
};
use std::{collections::HashSet, env};
use types::{
    keys::{self, KeyType},
    proofs::{
        evm::{account::Account, storage::Storage},
        header::{Header, HeaderPayload, HeaderProof},
        mmr::MmrMeta,
        mpt::MPTProof,
        HeaderMmrMeta,
    },
    ETH_RPC,
};

use crate::FetcherError;
use cairo_vm::Felt252;

pub mod evm;
pub mod starknet;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub evm: evm::ProofKeys,
    pub starknet: starknet::ProofKeys,
}


impl ProofKeys {
    pub fn new() -> Self {
        Self {
            evm: evm::ProofKeys::default(),
            starknet: starknet::ProofKeys::default(),
        }
    }

    fn normalize_hex(input: &str) -> String {
        let hex_str = input.trim_start_matches("0x");
        format!("{:0>width$}", hex_str, width = (hex_str.len() + 1) / 2 * 2)
    }

    pub async fn fetch_header_proof(chain_id: u128, block_number: u64) -> Result<HeaderMmrMeta, FetcherError> {
        let provider = Indexer::default();

        // Fetch proof response
        let response = provider
            .get_headers_proof(IndexerQuery::new(chain_id, block_number, block_number))
            .await?;

        // Extract MMR metadata
        let mmr_meta = MmrMeta {
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

        let mmr_proof = response
            .headers
            .get(&block_number)
            .ok_or_else(|| FetcherError::InternalError("block not found".into()))?;

        let payload = match KeyType::from(chain_id) {
            KeyType::EVM => {
                match &mmr_proof.block_header {
                    BlockHeader::RlpString(rlp) => {
                        let bytes: Bytes = rlp.parse()?;
                        HeaderPayload::Evm(bytes)
                    },
                    BlockHeader::RlpLittleEndian8ByteChunks(rlp) => {
                        let rlp_chunks: Vec<Bytes> = rlp
                            .clone()
                            .iter()
                            .map(|x| Self::normalize_hex(x).parse())
                            .collect::<Result<Vec<Bytes>, FromHexError>>()?;
                        HeaderPayload::Evm(rlp_chunks.iter().flat_map(|x| x.iter().rev().cloned()).collect::<Vec<u8>>().into())
                    }
                    _ => return Err(FetcherError::InternalError("wrong rlp format".into())),
                }
            },
            KeyType::STARKNET => {
                unimplemented!()
            }
        };

        // Construct Header
        let header = Header {
            payload,
            proof: HeaderProof {
                leaf_idx: mmr_proof.element_index,
                mmr_path: mmr_proof
                    .siblings_hashes
                    .iter()
                    .map(|hash| Felt252::from_bytes_be_slice(&Self::normalize_hex(hash).as_bytes()))
                    .collect::<Vec<Felt252>>()
            },
        };

        Ok(HeaderMmrMeta {
            mmr_meta,
            headers: vec![header],
        })
    }



}