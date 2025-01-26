use alloy::{
    hex::FromHexError,
    primitives::{Bytes, U256},
    providers::{Provider, RootProvider},
    transports::http::{reqwest::Url, Client, Http},
};
use cairo_vm::Felt252;
use eth_trie_proofs::{tx_receipt_trie::TxReceiptsMptHandler, tx_trie::TxsMptHandler};
use indexer::models::BlockHeader;
use starknet_types_core::felt::FromStrError;
use std::{collections::HashSet, env};
use types::{
    keys,
    proofs::{
        evm::{account::Account, header::Header, receipt::Receipt, storage::Storage, transaction::Transaction},
        header::{HeaderMmrMeta, HeaderProof},
        mpt::MPTProof,
    },
    RPC_URL_ETHEREUM,
};

use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::evm::header::Key>,
    pub account_keys: HashSet<keys::evm::account::Key>,
    pub storage_keys: HashSet<keys::evm::storage::Key>,
    pub receipt_keys: HashSet<keys::evm::receipt::Key>,
    pub transaction_keys: HashSet<keys::evm::transaction::Key>,
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
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            Self::fetch_header_proof(key.chain_id, key.block_number).await?,
            Account::new(value.address, vec![MPTProof::new(key.block_number, value.account_proof)]),
        ))
    }

    pub async fn fetch_storage_proof(key: &keys::evm::storage::Key) -> Result<(HeaderMmrMeta<Header>, Account, Storage), FetcherError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap());
        let value = provider
            .get_proof(key.address, vec![key.storage_slot])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
            Self::fetch_header_proof(key.chain_id, key.block_number).await?,
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

    pub async fn fetch_receipt_proof(key: &keys::evm::receipt::Key) -> Result<(HeaderMmrMeta<Header>, Receipt), FetcherError> {
        let mut tx_receipts_mpt_handler = TxReceiptsMptHandler::new(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap())
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let header = Self::fetch_header_proof(key.chain_id, key.block_number).await?;
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

    pub async fn fetch_transaction_proof(key: &keys::evm::transaction::Key) -> Result<(HeaderMmrMeta<Header>, Transaction), FetcherError> {
        let mut tx_trie_handler =
            TxsMptHandler::new(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap()).map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let header = Self::fetch_header_proof(key.chain_id, key.block_number).await?;
        let tx_proof = Self::generate_block_tx_proof(&mut tx_trie_handler, key.block_number, key.transaction_index).await?;

        let rlp_encoded_key = alloy_rlp::encode(U256::from(key.transaction_index));
        Ok((header, Transaction::new(U256::from_be_slice(&rlp_encoded_key), tx_proof)))
    }
}
