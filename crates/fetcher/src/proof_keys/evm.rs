use std::collections::HashSet;

use alloy::{
    hex::FromHexError,
    network::Ethereum,
    primitives::{Bytes, U256},
    providers::{Provider, RootProvider},
    transports::http::reqwest::Url,
};
use cairo_vm::Felt252;
use eth_trie_proofs::{tx_receipt_trie::TxReceiptsMptHandler, tx_trie::TxsMptHandler};
use indexer::models::BlockHeader;
use starknet_types_core::felt::FromStrError;
use types::{
    keys::{self, evm::get_corresponding_rpc_url},
    proofs::{
        evm::{account::Account, header::Header, receipt::Receipt, storage::Storage, transaction::Transaction},
        header::{HeaderMmrMeta, HeaderProof},
        mpt::MPTProof,
    },
};

use super::FlattenedKey;
use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub account_keys: HashSet<keys::evm::account::Key>,
    pub header_keys: HashSet<keys::evm::header::Key>,
    pub receipt_keys: HashSet<keys::evm::receipt::Key>,
    pub storage_keys: HashSet<keys::evm::storage::Key>,
    pub transaction_keys: HashSet<keys::evm::transaction::Key>,
}

impl ProofKeys {
    fn normalize_hex(input: &str) -> String {
        let hex_str = input.trim_start_matches("0x");
        format!("{:0>width$}", hex_str, width = (hex_str.len() + 1) / 2 * 2)
    }

    pub async fn fetch_header_proof(
        deployed_on_chain_id: u128,
        accumulates_chain_id: u128,
        block_number: u64,
    ) -> Result<HeaderMmrMeta<Header>, FetcherError> {
        let (mmr_proof, meta) = super::ProofKeys::fetch_mmr_proof(deployed_on_chain_id, accumulates_chain_id, block_number).await?;

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

    pub async fn fetch_account_proof(key: &keys::evm::account::Key) -> Result<Account, FetcherError> {
        let rpc_url = get_corresponding_rpc_url(key).map_err(|e| FetcherError::InternalError(e.to_string()))?;
        let provider = RootProvider::<Ethereum>::new_http(Url::parse(&rpc_url).unwrap());
        let value = provider
            .get_proof(key.address, vec![])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok(Account::new(
            value.address,
            vec![MPTProof::new(key.block_number, value.account_proof)],
        ))
    }

    pub async fn fetch_storage_proof(key: &keys::evm::storage::Key) -> Result<(Account, Storage), FetcherError> {
        let rpc_url = get_corresponding_rpc_url(key).map_err(|e| FetcherError::InternalError(e.to_string()))?;
        let provider = RootProvider::<Ethereum>::new_http(Url::parse(&rpc_url).unwrap());
        let value = provider
            .get_proof(key.address, vec![key.storage_slot])
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;
        Ok((
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

    fn generate_block_tx_receipt_proof(
        tx_receipts_mpt_handler: &mut TxReceiptsMptHandler,
        block_number: u64,
        tx_index: u64,
    ) -> Result<MPTProof, FetcherError> {
        let trie_proof = tx_receipts_mpt_handler
            .get_proof(tx_index)
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        tx_receipts_mpt_handler
            .verify_proof(tx_index, trie_proof.clone())
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let proof = trie_proof.into_iter().map(Bytes::from).collect::<Vec<Bytes>>();
        Ok(MPTProof { block_number, proof })
    }

    pub fn compute_receipt_proof(
        key: &keys::evm::receipt::Key,
        tx_receipts_mpt_handler: &mut TxReceiptsMptHandler,
    ) -> Result<Receipt, FetcherError> {
        let receipt_mpt_proof = Self::generate_block_tx_receipt_proof(tx_receipts_mpt_handler, key.block_number, key.transaction_index)?;
        let rlp_encoded_key = alloy_rlp::encode(U256::from(key.transaction_index));

        Ok(Receipt::new(U256::from_be_slice(&rlp_encoded_key), receipt_mpt_proof))
    }

    fn generate_block_tx_proof(tx_trie_handler: &mut TxsMptHandler, block_number: u64, tx_index: u64) -> Result<MPTProof, FetcherError> {
        let trie_proof = tx_trie_handler
            .get_proof(tx_index)
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        tx_trie_handler
            .verify_proof(tx_index, trie_proof.clone())
            .map_err(|e| FetcherError::InternalError(e.to_string()))?;

        let proof = trie_proof.into_iter().map(Bytes::from).collect::<Vec<Bytes>>();
        Ok(MPTProof { block_number, proof })
    }

    pub fn compute_transaction_proof(
        key: &keys::evm::transaction::Key,
        tx_trie_handler: &mut TxsMptHandler,
    ) -> Result<Transaction, FetcherError> {
        let tx_proof = Self::generate_block_tx_proof(tx_trie_handler, key.block_number, key.transaction_index)?;

        let rlp_encoded_key = alloy_rlp::encode(U256::from(key.transaction_index));
        Ok(Transaction::new(U256::from_be_slice(&rlp_encoded_key), tx_proof))
    }

    pub fn to_flattened_keys(&self, chain_id: u128) -> HashSet<FlattenedKey> {
        let mut flattened = HashSet::new();

        for key in &self.header_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        for key in &self.account_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        for key in &self.storage_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        for key in &self.receipt_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        for key in &self.transaction_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        flattened
    }
}
