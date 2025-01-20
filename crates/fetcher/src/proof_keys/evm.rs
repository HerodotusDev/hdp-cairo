use alloy::{
    hex::FromHexError,
    primitives::Bytes,
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use cairo_vm::Felt252;
use indexer::models::BlockHeader;
use starknet_types_core::felt::FromStrError;
use std::{collections::HashSet, env};
use types::{
    keys,
    proofs::{
        evm::{account::Account, header::Header, storage::Storage},
        header::{HeaderMmrMeta, HeaderProof},
        mpt::MPTProof,
    },
    ETH_RPC,
};

use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::evm::header::Key>,
    pub account_keys: HashSet<keys::evm::account::Key>,
    pub storage_keys: HashSet<keys::evm::storage::Key>,
}

impl ProofKeys {
    fn normalize_hex(input: &str) -> String {
        let hex_str = input.trim_start_matches("0x");
        format!("{:0>width$}", hex_str, width = (hex_str.len() + 1) / 2 * 2)
    }

    pub async fn fetch_header_proof(chain_id: u128, block_number: u64) -> Result<HeaderMmrMeta<Header>, FetcherError> {
        let (mmr_proof, meta) = super::ProofKeys::fetch_mmr_proof(chain_id, block_number).await?;

        let proof = HeaderProof {
            leaf_idx: mmr_proof.element_index,
            mmr_path: mmr_proof
                .siblings_hashes
                .iter()
                .map(|hash| Felt252::from_hex(hash.as_str()))
                .collect::<Result<Vec<Felt252>, FromStrError>>()?,
        };

        let rlp = match &mmr_proof.block_header {
            BlockHeader::RlpString(rlp) => {
                let bytes: Bytes = rlp.parse()?;
                bytes
            }
            BlockHeader::RlpLittleEndian8ByteChunks(rlp) => {
                let rlp_chunks: Vec<Bytes> = rlp
                    .clone()
                    .iter()
                    .map(|x| Self::normalize_hex(x).parse())
                    .collect::<Result<Vec<Bytes>, FromHexError>>()?;
                rlp_chunks.iter().flat_map(|x| x.iter().rev().cloned()).collect::<Vec<u8>>().into()
            }
            _ => return Err(FetcherError::InternalError("wrong rlp format".into())),
        };
        Ok(HeaderMmrMeta {
            mmr_meta: meta,
            headers: vec![Header { rlp, proof }],
        })
    }

    pub async fn fetch_account_proof(key: &keys::evm::account::Key) -> Result<(HeaderMmrMeta<Header>, Account), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(ETH_RPC).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            ProofKeys::fetch_header_proof(key.chain_id, key.block_number).await?,
            Account::new(value.address, vec![MPTProof::new(key.block_number, value.account_proof)]),
        ))
    }

    pub async fn fetch_storage_proof(key: &keys::evm::storage::Key) -> Result<(HeaderMmrMeta<Header>, Account, Storage), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(ETH_RPC).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![key.storage_slot])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            ProofKeys::fetch_header_proof(key.chain_id, key.block_number).await?,
            Account::new(value.address, vec![MPTProof::new(key.block_number, value.account_proof)]),
            Storage::new(
                value.address,
                key.storage_slot,
                vec![MPTProof::new(
                    key.block_number,
                    value.storage_proof.into_iter().flat_map(|f| f.proof).collect(),
                )],
            ),
        ))
    }
}
