use std::{
    collections::{HashMap, HashSet},
    env,
    num::ParseIntError,
};

use alloy::hex::FromHexError;
use dry_hint_processor::syscall_handler::{evm, starknet};
use eth_trie_proofs::{tx_receipt_trie::TxReceiptsMptHandler, tx_trie::TxsMptHandler};
use futures::StreamExt;
use indexer::models::IndexerError;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use proof_keys::{evm::ProofKeys as EvmProofKeys, starknet::ProofKeys as StarknetProofKeys, FlattenedKey, ProofKeys};
use reqwest::Url;
use starknet_types_core::felt::FromStrError;
use syscall_handler::SyscallHandler;
use thiserror::Error;
use types::{
    proofs::{
        evm::{
            account::Account, header::Header as EvmHeader, receipt::Receipt, storage::Storage, transaction::Transaction,
            Proofs as EvmProofs,
        },
        header::HeaderMmrMeta,
        mmr::MmrMeta,
        starknet::{header::Header as StarknetHeader, storage::Storage as StarknetStorage, Proofs as StarknetProofs},
    },
    RPC_URL_ETHEREUM,
};

pub mod proof_keys;

#[derive(Error, Debug)]
pub enum FetcherError {
    #[error(transparent)]
    Args(#[from] clap::error::Error),
    #[error("Output Error: {0}")]
    Output(String),
    #[error(transparent)]
    IO(#[from] std::io::Error),
    #[error(transparent)]
    Indexer(#[from] IndexerError),
    #[error(transparent)]
    ParseIntError(#[from] ParseIntError),
    #[error(transparent)]
    FromHexError(#[from] FromHexError),
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
    #[error("Internal Error: {0}")]
    InternalError(String),
    #[error("HTTP request failed: {0}")]
    RequestError(#[from] reqwest::Error),
    #[error("JSON deserialization error: {0}")]
    JsonDeserializationError(String),
}

impl From<FromStrError> for FetcherError {
    fn from(e: FromStrError) -> Self {
        FetcherError::InternalError(e.to_string())
    }
}

const BUFFER_UNORDERED: usize = 50;

pub struct ProgressBars {
    pub evm_header: Option<ProgressBar>,
    pub evm_account: Option<ProgressBar>,
    pub evm_storage: Option<ProgressBar>,
    pub evm_receipts: Option<ProgressBar>,
    pub evm_transactions: Option<ProgressBar>,
    pub starknet_header: Option<ProgressBar>,
    pub starknet_storage: Option<ProgressBar>,
}

impl ProgressBars {
    pub fn new(proof_keys: &ProofKeys) -> Self {
        let multi_progress = MultiProgress::new();
        #[allow(clippy::literal_string_with_formatting_args)]
        let style = ProgressStyle::with_template("[{elapsed_precise}] [{bar:40}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("=> ");

        let bars = [
            (proof_keys.evm.header_keys.len(), "ethereum header keys - fetching"),
            (proof_keys.evm.account_keys.len(), "ethereum account key - fetching"),
            (proof_keys.evm.storage_keys.len(), "ethereum storage keys - fetching"),
            (proof_keys.evm.receipt_keys.len(), "ethereum receipts keys - fetching"),
            (proof_keys.evm.transaction_keys.len(), "ethereum transactions keys - fetching"),
            (proof_keys.starknet.header_keys.len(), "starknet header keys - fetching"),
            (proof_keys.starknet.storage_keys.len(), "starknet storage keys - fetching"),
        ]
        .map(|(len, msg)| {
            let pb = multi_progress.add(ProgressBar::new(len as u64));
            pb.set_style(style.clone());
            pb.set_message(msg);
            Some(pb)
        });

        Self {
            evm_header: bars[0].clone(),
            evm_account: bars[1].clone(),
            evm_storage: bars[2].clone(),
            evm_receipts: bars[3].clone(),
            evm_transactions: bars[4].clone(),
            starknet_header: bars[5].clone(),
            starknet_storage: bars[6].clone(),
        }
    }
}

#[cfg(feature = "progress_bars")]
// Helper trait to safely increment progress
trait ProgressExt {
    fn safe_inc(&self);
    fn safe_finish_with_message(&self, msg: &'static str);
}

#[cfg(feature = "progress_bars")]
impl ProgressExt for Option<ProgressBar> {
    fn safe_inc(&self) {
        if let Some(pb) = self {
            pb.inc(1);
        }
    }

    fn safe_finish_with_message(&self, msg: &'static str) {
        if let Some(pb) = self {
            pb.finish_with_message(msg);
        }
    }
}

pub struct Fetcher<'a> {
    proof_keys: &'a ProofKeys,
    #[cfg(feature = "progress_bars")]
    progress_bars: ProgressBars,
}
impl<'a> Fetcher<'a> {
    pub fn new(proof_keys: &'a ProofKeys) -> Self {
        Self {
            proof_keys,
            #[cfg(feature = "progress_bars")]
            progress_bars: ProgressBars::new(proof_keys),
        }
    }

    async fn collect_evm_headers_proofs(
        &self,
        flattened_keys: &HashSet<FlattenedKey>,
    ) -> Result<HashMap<MmrMeta, Vec<EvmHeader>>, FetcherError> {
        let mut headers_with_mmr = HashMap::default();
        let mut header_fut = futures::stream::iter(
            flattened_keys
                .iter()
                .map(|key| EvmProofKeys::fetch_header_proof(key.chain_id, key.block_number)),
        )
        .buffer_unordered(BUFFER_UNORDERED)
        .boxed();

        while let Some(result) = header_fut.next().await {
            let item = result?;
            headers_with_mmr
                .entry(item.mmr_meta)
                .and_modify(|headers: &mut Vec<EvmHeader>| headers.extend(item.headers.clone()))
                .or_insert(item.headers);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_header.safe_inc();
        }

        Ok(headers_with_mmr)
    }

    pub async fn collect_evm_proofs(&self) -> Result<EvmProofs, FetcherError> {
        let mut accounts: HashSet<Account> = HashSet::default();
        let mut storages: HashSet<Storage> = HashSet::default();
        let mut receipts: HashSet<Receipt> = HashSet::default();
        let mut transactions: HashSet<Transaction> = HashSet::default();

        let flattened_keys = self.proof_keys.evm.to_flattened_keys();

        // Collect required header proofs for all keys
        let headers_with_mmr = self.collect_evm_headers_proofs(&flattened_keys).await?;

        #[cfg(feature = "progress_bars")]
        self.progress_bars.evm_header.safe_finish_with_message("evm header keys - finished");

        // Collect account proofs
        let mut account_fut = futures::stream::iter(self.proof_keys.evm.account_keys.iter().map(EvmProofKeys::fetch_account_proof))
            .buffer_unordered(BUFFER_UNORDERED)
            .boxed();

        while let Some(result) = account_fut.next().await {
            accounts.insert(result?);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_account.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_account
            .safe_finish_with_message("evm account keys - finished");

        // Collect storage proofs
        let mut storage_fut = futures::stream::iter(self.proof_keys.evm.storage_keys.iter().map(EvmProofKeys::fetch_storage_proof))
            .buffer_unordered(BUFFER_UNORDERED)
            .boxed();

        while let Some(result) = storage_fut.next().await {
            let (account, storage) = result?;
            accounts.insert(account);
            storages.insert(storage);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_storage.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_storage
            .safe_finish_with_message("evm storage keys - finished");

        // For each block, we need to create a mpt_handler
        let mut receipt_mpt_handlers: HashMap<u64, TxReceiptsMptHandler> = HashMap::default();

        for block_number in self.proof_keys.evm.receipt_keys.iter().map(|key| key.block_number) {
            if let std::collections::hash_map::Entry::Vacant(entry) = receipt_mpt_handlers.entry(block_number) {
                let mut mpt_handler = TxReceiptsMptHandler::new(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap())
                    .map_err(|e| FetcherError::InternalError(e.to_string()))?;

                mpt_handler
                    .build_tx_receipts_tree_from_block(block_number)
                    .await
                    .map_err(|e| FetcherError::InternalError(e.to_string()))?;

                entry.insert(mpt_handler);
            }

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_receipts.safe_inc();
        }

        receipts.extend(
            self.proof_keys
                .evm
                .receipt_keys
                .iter()
                .map(|key| EvmProofKeys::compute_receipt_proof(key, receipt_mpt_handlers.get_mut(&key.block_number).unwrap()).unwrap()),
        );

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_receipts
            .safe_finish_with_message("evm receipt keys - finished");

        // For each tx block, we need to create a mpt_handler
        let mut tx_mpt_handlers: HashMap<u64, TxsMptHandler> = HashMap::default();

        for key in self.proof_keys.evm.transaction_keys.iter() {
            if let std::collections::hash_map::Entry::Vacant(entry) = tx_mpt_handlers.entry(key.block_number) {
                let mut mpt_handler = TxsMptHandler::new(Url::parse(&env::var(RPC_URL_ETHEREUM).unwrap()).unwrap())
                    .map_err(|e| FetcherError::InternalError(e.to_string()))?;

                mpt_handler
                    .build_tx_tree_from_block(key.block_number)
                    .await
                    .map_err(|e| FetcherError::InternalError(e.to_string()))?;

                entry.insert(mpt_handler);
            }

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_transactions.safe_inc();
        }

        transactions.extend(
            self.proof_keys
                .evm
                .transaction_keys
                .iter()
                .map(|key| EvmProofKeys::compute_transaction_proof(key, tx_mpt_handlers.get_mut(&key.block_number).unwrap()).unwrap()),
        );

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_transactions
            .safe_finish_with_message("evm storage keys - finished");

        Ok(EvmProofs {
            headers_with_mmr: process_headers(headers_with_mmr),
            accounts: accounts.into_iter().collect(),
            storages: storages.into_iter().collect(),
            transaction_receipts: receipts.into_iter().collect(),
            transactions: transactions.into_iter().collect(),
        })
    }

    async fn collect_starknet_headers_proofs(
        &self,
        flattened_keys: &HashSet<FlattenedKey>,
    ) -> Result<HashMap<MmrMeta, Vec<StarknetHeader>>, FetcherError> {
        let mut headers_with_mmr = HashMap::default();
        let mut header_fut = futures::stream::iter(
            flattened_keys
                .iter()
                .map(|key| StarknetProofKeys::fetch_header_proof(key.chain_id, key.block_number)),
        )
        .buffer_unordered(BUFFER_UNORDERED)
        .boxed();

        while let Some(result) = header_fut.next().await {
            let item = result?;
            headers_with_mmr
                .entry(item.mmr_meta)
                .and_modify(|headers: &mut Vec<StarknetHeader>| headers.extend(item.headers.clone()))
                .or_insert(item.headers);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.starknet_header.safe_inc();
        }

        Ok(headers_with_mmr)
    }

    pub async fn collect_starknet_proofs(&self) -> Result<StarknetProofs, FetcherError> {
        let mut storages: HashSet<StarknetStorage> = HashSet::default();

        let flattened_keys = self.proof_keys.starknet.to_flattened_keys();

        let headers_with_mmr = self.collect_starknet_headers_proofs(&flattened_keys).await?;

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .starknet_header
            .safe_finish_with_message("starknet header keys - finished");

        // Collect storage proofs
        let mut storage_fut = futures::stream::iter(
            self.proof_keys
                .starknet
                .storage_keys
                .iter()
                .map(StarknetProofKeys::fetch_storage_proof),
        )
        .buffer_unordered(BUFFER_UNORDERED)
        .boxed();

        while let Some(result) = storage_fut.next().await {
            storages.insert(result?);
            #[cfg(feature = "progress_bars")]
            self.progress_bars.starknet_storage.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .starknet_storage
            .safe_finish_with_message("starknet storage keys - finished");

        Ok(StarknetProofs {
            headers_with_mmr: process_headers(headers_with_mmr),
            storages: storages.into_iter().collect(),
        })
    }
}

pub fn process_headers<H>(headers_with_mmr: HashMap<MmrMeta, Vec<H>>) -> Vec<HeaderMmrMeta<H>>
where
    H: Eq + std::hash::Hash + Clone,
{
    headers_with_mmr
        .into_iter()
        .map(|(mmr_meta, headers)| {
            let unique_headers: Vec<_> = headers.into_iter().collect::<HashSet<_>>().into_iter().collect();
            HeaderMmrMeta {
                headers: unique_headers,
                mmr_meta,
            }
        })
        .collect()
}

pub fn parse_syscall_handler(
    syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>,
) -> Result<ProofKeys, FetcherError> {
    let mut proof_keys = ProofKeys::default();

    // Process EVM keys
    for key in syscall_handler.call_contract_handler.evm_call_contract_handler.key_set {
        match key {
            evm::DryRunKey::Account(value) => proof_keys.evm.account_keys.insert(value),
            evm::DryRunKey::Header(value) => proof_keys.evm.header_keys.insert(value),
            evm::DryRunKey::Storage(value) => proof_keys.evm.storage_keys.insert(value),
            evm::DryRunKey::Receipt(value) => proof_keys.evm.receipt_keys.insert(value),
            evm::DryRunKey::Tx(value) => proof_keys.evm.transaction_keys.insert(value),
        };
    }

    // Process Starknet keys
    for key in syscall_handler.call_contract_handler.starknet_call_contract_handler.key_set {
        match key {
            starknet::DryRunKey::Header(value) => proof_keys.starknet.header_keys.insert(value),
            starknet::DryRunKey::Storage(value) => proof_keys.starknet.storage_keys.insert(value),
        };
    }

    Ok(proof_keys)
}
