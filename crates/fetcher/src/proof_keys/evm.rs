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
    keys,
    proofs::{
        evm::account::Account,
        header::{Header, HeaderProof},
        mmr::MmrMeta,
        mpt::MPTProof,
        evm::storage::Storage,
        HeaderMmrMeta,
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
    pub async fn fetch_account_proof(key: &keys::evm::account::Key) -> Result<(HeaderMmrMeta, Account), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(ETH_RPC).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            super::ProofKeys::fetch_header_proof(key.chain_id, key.block_number).await?,
            Account::new(value.address, vec![MPTProof::new(key.block_number, value.account_proof)]),
        ))
    }

    pub async fn fetch_storage_proof(key: &keys::evm::storage::Key) -> Result<(HeaderMmrMeta, Account, Storage), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(ETH_RPC).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![key.storage_slot])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            super::ProofKeys::fetch_header_proof(key.chain_id, key.block_number).await?,
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
