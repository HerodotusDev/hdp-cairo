use std::{
    collections::{HashMap, HashSet},
    num::ParseIntError,
};

use alloy::hex::FromHexError;
use dry_hint_processor::syscall_handler::{evm, starknet, SyscallHandler};
use futures::StreamExt;
use indexer::models::IndexerError;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use proof_keys::{evm::ProofKeys as EvmProofKeys, starknet::ProofKeys as StarknetProofKeys, ProofKeys};
use starknet_types_core::felt::FromStrError;
use thiserror::Error;
use types::proofs::{
    evm::{
        account::Account, header::Header as EvmHeader, receipt::Receipt, storage::Storage, transaction::Transaction, Proofs as EvmProofs,
    },
    header::HeaderMmrMeta,
    mmr::MmrMeta,
    starknet::{header::Header as StarknetHeader, storage::Storage as StarknetStorage, Proofs as StarknetProofs},
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

    pub async fn collect_evm_proofs(&self) -> Result<EvmProofs, FetcherError> {
        let mut headers_with_mmr = HashMap::default();
        let mut accounts: HashSet<Account> = HashSet::default();
        let mut storages: HashSet<Storage> = HashSet::default();
        let mut receipts: HashSet<Receipt> = HashSet::default();
        let mut transactions: HashSet<Transaction> = HashSet::default();

        // Collect header proofs
        let mut header_fut = futures::stream::iter(
            self.proof_keys
                .evm
                .header_keys
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

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_header
            .safe_finish_with_message("ethereum header keys - finished");

        // Collect account proofs
        let mut account_fut = futures::stream::iter(self.proof_keys.evm.account_keys.iter().map(EvmProofKeys::fetch_account_proof))
            .buffer_unordered(BUFFER_UNORDERED)
            .boxed();

        while let Some(result) = account_fut.next().await {
            let (header_with_mmr, account) = result?;
            headers_with_mmr
                .entry(header_with_mmr.mmr_meta)
                .and_modify(|headers: &mut Vec<EvmHeader>| headers.extend(header_with_mmr.headers.clone()))
                .or_insert(header_with_mmr.headers);
            accounts.insert(account);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_account.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_account
            .safe_finish_with_message("ethereum account keys - finished");

        // Collect storage proofs
        let mut storage_fut = futures::stream::iter(self.proof_keys.evm.storage_keys.iter().map(EvmProofKeys::fetch_storage_proof))
            .buffer_unordered(BUFFER_UNORDERED)
            .boxed();

        while let Some(result) = storage_fut.next().await {
            let (header_with_mmr, account, storage) = result?;
            headers_with_mmr
                .entry(header_with_mmr.mmr_meta)
                .and_modify(|headers: &mut Vec<EvmHeader>| headers.extend(header_with_mmr.headers.clone()))
                .or_insert(header_with_mmr.headers);
            accounts.insert(account);
            storages.insert(storage);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_storage.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_storage
            .safe_finish_with_message("ethereum storage keys - finished");

        // Collect ransaction receipts proofs
        let mut transaction_receipts_fut =
            futures::stream::iter(self.proof_keys.evm.receipt_keys.iter().map(EvmProofKeys::fetch_receipt_proof))
                .buffer_unordered(BUFFER_UNORDERED)
                .boxed();

        while let Some(Ok((header_with_mmr, transaction_receipt))) = transaction_receipts_fut.next().await {
            headers_with_mmr
                .entry(header_with_mmr.mmr_meta)
                .and_modify(|headers: &mut Vec<EvmHeader>| headers.extend(header_with_mmr.headers.clone()))
                .or_insert(header_with_mmr.headers);
            receipts.insert(transaction_receipt);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_receipts.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_receipts
            .safe_finish_with_message("ethereum receipt keys - finished");

        // Collect storage proofs
        let mut transaction_keys_fut = futures::stream::iter(
            self.proof_keys
                .evm
                .transaction_keys
                .iter()
                .map(EvmProofKeys::fetch_transaction_proof),
        )
        .buffer_unordered(BUFFER_UNORDERED)
        .boxed();

        while let Some(Ok((header_with_mmr, transaction))) = transaction_keys_fut.next().await {
            headers_with_mmr
                .entry(header_with_mmr.mmr_meta)
                .and_modify(|headers: &mut Vec<EvmHeader>| headers.extend(header_with_mmr.headers.clone()))
                .or_insert(header_with_mmr.headers);
            transactions.insert(transaction);

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_transactions.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_transactions
            .safe_finish_with_message("ethereum storage keys - finished");

        Ok(EvmProofs {
            headers_with_mmr: process_headers(headers_with_mmr),
            accounts: accounts.into_iter().collect(),
            storages: storages.into_iter().collect(),
            transaction_receipts: receipts.into_iter().collect(),
            transactions: transactions.into_iter().collect(),
        })
    }

    pub async fn collect_starknet_proofs(&self) -> Result<StarknetProofs, FetcherError> {
        let mut headers_with_mmr = HashMap::default();
        let mut storages: HashSet<StarknetStorage> = HashSet::default();

        // Collect header proofs
        let mut header_fut = futures::stream::iter(
            self.proof_keys
                .starknet
                .header_keys
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
            let (header_with_mmr, storage) = result?;
            headers_with_mmr
                .entry(header_with_mmr.mmr_meta)
                .and_modify(|headers: &mut Vec<StarknetHeader>| headers.extend(header_with_mmr.headers.clone()))
                .or_insert(header_with_mmr.headers);
            storages.insert(storage);

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

pub fn parse_syscall_handler(syscall_handler: SyscallHandler) -> Result<ProofKeys, FetcherError> {
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
