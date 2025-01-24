use crate::FetcherError;

use alloy::{
    hex::FromHexError,
    primitives::{Bytes, U256},
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use eth_trie_proofs::{tx_receipt_trie::TxReceiptsMptHandler, tx_trie::TxsMptHandler};
use indexer::{
    types::{BlockHeader, IndexerQuery},
    Indexer,
};
use std::{collections::HashSet, env};
use types::{
    keys,
    proofs::{
        account::Account,
        header::{Header, HeaderProof},
        mmr::MmrMeta,
        mpt::MPTProof,
        receipt::Receipt,
        storage::Storage,
        transaction::Transaction,
        HeaderMmrMeta,
    },
    RPC,
};

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::header::Key>,
    pub account_keys: HashSet<keys::account::Key>,
    pub storage_keys: HashSet<keys::storage::Key>,
    pub receipt_keys: HashSet<keys::receipt::Key>,
    pub tx_keys: HashSet<keys::transaction::Key>,
}

impl ProofKeys {
    fn normalize_hex(input: &str) -> String {
        let hex_str = input.trim_start_matches("0x");
        format!("{:0>width$}", hex_str, width = (hex_str.len() + 1) / 2 * 2)
    }

    pub async fn fetch_header_proof(key: &keys::header::Key) -> Result<HeaderMmrMeta, FetcherError> {
        let provider = Indexer::default();

        // Fetch proof response
        let response = provider
            .get_headers_proof(IndexerQuery::new(key.chain_id, key.block_number, key.block_number))
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
            .get(&key.block_number)
            .ok_or_else(|| FetcherError::InternalError("block not found".into()))?;

        // Parse RLP
        let rlp: Bytes = match &mmr_proof.block_header {
            BlockHeader::RlpString(rlp) => rlp.parse()?,
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

        // Construct Header
        let header = Header {
            rlp,
            proof: HeaderProof {
                leaf_idx: mmr_proof.element_index,
                mmr_path: mmr_proof
                    .siblings_hashes
                    .iter()
                    .map(|hash| Self::normalize_hex(hash).parse())
                    .collect::<Result<Vec<Bytes>, FromHexError>>()?,
            },
        };

        Ok(HeaderMmrMeta {
            mmr_meta,
            headers: vec![header],
        })
    }

    pub async fn fetch_account_proof(key: &keys::account::Key) -> Result<(HeaderMmrMeta, Account), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            Self::fetch_header_proof(&key.to_owned().into()).await?,
            Account::new(value.address, vec![MPTProof::new(key.block_number, value.account_proof)]),
        ))
    }

    pub async fn fetch_storage_proof(key: &keys::storage::Key) -> Result<(HeaderMmrMeta, Account, Storage), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![key.storage_slot])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            Self::fetch_header_proof(&key.to_owned().into()).await?,
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

    async fn generate_block_tx_receipt_proof(
        tx_receipts_mpt_handler: &mut TxReceiptsMptHandler,
        block_number: u64,
        tx_index: u64,
    ) -> Result<MPTProof, FetcherError> {
        tx_receipts_mpt_handler
            .build_tx_receipts_tree_from_block(block_number)
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        let trie_proof = tx_receipts_mpt_handler
            .get_proof(tx_index)
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        tx_receipts_mpt_handler
            .verify_proof(tx_index, trie_proof.clone())
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let proof = trie_proof.into_iter().map(Bytes::from).collect::<Vec<Bytes>>();
        Ok(MPTProof { block_number, proof })
    }

    pub async fn fetch_receipt_proof(key: &keys::receipt::Key) -> Result<(HeaderMmrMeta, Receipt), FetcherError> {
        let mut tx_receipts_mpt_handler =
            TxReceiptsMptHandler::new(Url::parse(&env::var(RPC).unwrap()).unwrap()).map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let header = Self::fetch_header_proof(&key.to_owned().into()).await?;
        let receipt_mpt_proof = Self::generate_block_tx_receipt_proof(&mut tx_receipts_mpt_handler, key.block_number, key.transaction_index).await?;

        let rlp_encoded_key = alloy_rlp::encode(U256::from(key.transaction_index));
        Ok((header, Receipt::new(U256::from_be_slice(&rlp_encoded_key), receipt_mpt_proof)))
    }

    async fn generate_block_tx_proof(tx_trie_handler: &mut TxsMptHandler, block_number: u64, tx_index: u64) -> Result<MPTProof, FetcherError> {
        tx_trie_handler
            .build_tx_tree_from_block(block_number)
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        let trie_proof = tx_trie_handler
            .get_proof(tx_index)
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        tx_trie_handler
            .verify_proof(tx_index, trie_proof.clone())
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let proof = trie_proof.into_iter().map(Bytes::from).collect::<Vec<Bytes>>();
        Ok(MPTProof { block_number, proof })
    }

    pub async fn fetch_transaction_proof(key: &keys::transaction::Key) -> Result<(HeaderMmrMeta, Transaction), FetcherError> {
        let mut tx_trie_handler =
            TxsMptHandler::new(Url::parse(&env::var(RPC).unwrap()).unwrap()).map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let header = Self::fetch_header_proof(&key.to_owned().into()).await?;
        let tx_proof = Self::generate_block_tx_proof(&mut tx_trie_handler, key.block_number, key.transaction_index).await?;

        let rlp_encoded_key = alloy_rlp::encode(U256::from(key.transaction_index));
        Ok((header, Transaction::new(U256::from_be_slice(&rlp_encoded_key), tx_proof)))
    }
}
