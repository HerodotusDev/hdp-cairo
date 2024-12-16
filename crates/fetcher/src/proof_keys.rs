use alloy::{
    hex::FromHexError,
    primitives::Bytes,
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use hdp_hint_processor::{
    hint_processor::models::proofs::{
        account::Account,
        header::{Header, HeaderProof},
        mmr::MmrMeta,
        mpt::MPTProof,
        storage::Storage,
    },
    syscall_handler::keys,
};
use provider::{
    indexer::{
        types::{BlockHeader, IndexerQuery},
        Indexer,
    },
    RPC,
};
use std::{collections::HashSet, env};

use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::header::Key>,
    pub account_keys: HashSet<keys::account::Key>,
    pub storage_keys: HashSet<keys::storage::Key>,
}

impl ProofKeys {
    pub fn fetch_header_proof(key: &keys::header::Key) -> Result<(MmrMeta, Header), FetcherError> {
        let provider = Indexer::default();
        let runtime = tokio::runtime::Runtime::new().unwrap();

        // Fetch proof response
        let response = runtime.block_on(async {
            provider
                .get_headers_proof(IndexerQuery::new(key.chain_id, key.block_number, key.block_number))
                .await
        })?;

        // Extract MMR metadata
        let mmr_meta = MmrMeta {
            id: u64::from_str_radix(&response.mmr_meta.mmr_id[2..], 16)?,
            size: response.mmr_meta.mmr_size,
            root: response.mmr_meta.mmr_root.parse()?,
            chain_id: key.chain_id,
            peaks: response
                .mmr_meta
                .mmr_peaks
                .iter()
                .map(|peak| peak.parse())
                .collect::<Result<Vec<Bytes>, FromHexError>>()?,
        };

        // Retrieve MMR proof
        let mmr_proof = response
            .headers
            .get(&key.block_number)
            .ok_or_else(|| FetcherError::InternalError("block not found".into()))?;

        // Parse RLP
        let rlp = match &mmr_proof.block_header {
            BlockHeader::RlpString(rlp) => rlp,
            _ => return Err(FetcherError::InternalError("wrong rlp format".into())),
        };

        // Construct Header
        let header = Header {
            rlp: rlp.parse()?,
            proof: HeaderProof {
                leaf_idx: mmr_proof.element_index,
                mmr_path: mmr_proof
                    .siblings_hashes
                    .iter()
                    .map(|hash| hash.parse())
                    .collect::<Result<Vec<Bytes>, FromHexError>>()?,
            },
        };

        Ok((mmr_meta, header))
    }

    pub fn fetch_account_proof(key: &keys::account::Key) -> Result<((MmrMeta, Header), Account), FetcherError> {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let value = runtime
            .block_on(async { provider.get_proof(key.address, vec![]).block_id(key.block_number.into()).await })
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            Self::fetch_header_proof(&key.to_owned().into())?,
            Account::new(value.address, vec![MPTProof::new(key.block_number, value.account_proof)]),
        ))
    }

    pub fn fetch_storage_proof(key: &keys::storage::Key) -> Result<((MmrMeta, Header), Account, Storage), FetcherError> {
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let value = runtime
            .block_on(async {
                provider
                    .get_proof(key.address, vec![key.storage_slot])
                    .block_id(key.block_number.into())
                    .await
            })
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            Self::fetch_header_proof(&key.to_owned().into())?,
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
