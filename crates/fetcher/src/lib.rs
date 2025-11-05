#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{
    collections::{HashMap, HashSet},
    num::ParseIntError,
    ops::RangeInclusive,
    path::PathBuf,
};

use alloy::{hex::FromHexError, primitives::Bytes};
use clap::Parser;
use dotenvy as _;
use dry_hint_processor::syscall_handler::{
    evm,
    injected_state::{self},
    starknet, unconstrained,
};
use eth_trie_proofs::{tx_receipt_trie::TxReceiptsMptHandler, tx_trie::TxsMptHandler};
use futures::StreamExt;
use indexer_client::{
    models::{ranges::FunctionsRanges, IndexerError, MMRDeploymentConfig, MMRHasherConfig},
    Indexer,
};
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use proof_keys::{
    evm::ProofKeys as EvmProofKeys, starknet::ProofKeys as StarknetProofKeys, unconstrained::ProofKeys as UnconstrainedProofKeys,
    FlattenedKey, ProofKeys,
};
use reqwest::Url;
use starknet_types_core::felt::FromStrError;
use state_server::api::proof::{GetStateProofsRequest, GetStateProofsResponse};
use syscall_handler::SyscallHandler;
use thiserror::Error;
use tokio as _;
use types::{
    cairo::unconstrained::UnconstrainedStateValue,
    keys::evm::get_corresponding_rpc_url,
    proofs::{
        evm::{
            account::Account, header::Header as EvmHeader, receipt::Receipt, storage::Storage, transaction::Transaction,
            Proofs as EvmProofs,
        },
        header::HeaderMmrMeta,
        injected_state::StateProofs,
        mmr::MmrMeta,
        starknet::{header::Header as StarknetHeader, storage::Storage as StarknetStorage, Proofs as StarknetProofs},
    },
    HashingFunction, UnconstrainedState,
};

pub mod proof_keys;

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    #[arg(
        short = 'i',
        long = "inputs",
        default_value = "dry_run_output.json",
        help = "The output of the dry_run step"
    )]
    pub inputs: PathBuf,
    #[arg(
        short = 'o',
        long = "output",
        default_value = "proofs.json",
        help = "Path where the output JSON will be written"
    )]
    pub output: PathBuf,
    #[arg(
        long = "mmr-hasher-config",
        help = "Path to JSON file containing fetcher config - mapping chain_id -> to mmr_hashing_function"
    )]
    pub mmr_hasher_config: Option<PathBuf>,

    #[arg(
        long = "mmr-deployment-config",
        help = "Path to JSON file containing fetcher config - mapping chain_id -> to chain_id"
    )]
    pub mmr_deployment_config: Option<PathBuf>,
}

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

const BUFFER_UNORDERED: usize = 10;

pub struct ProgressBars {
    pub evm_header: Option<ProgressBar>,
    pub evm_account: Option<ProgressBar>,
    pub evm_storage: Option<ProgressBar>,
    pub evm_receipts: Option<ProgressBar>,
    pub evm_transactions: Option<ProgressBar>,
    pub starknet_header: Option<ProgressBar>,
    pub starknet_storage: Option<ProgressBar>,
    pub unconstrained_bytecode: Option<ProgressBar>,
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
            (proof_keys.unconstrained.bytecode.len(), "unconstrained bytecode keys - fetching"),
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
            unconstrained_bytecode: bars[7].clone(),
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
    mmr_hasher_config: MMRHasherConfig,
    mmr_deployment_config: MMRDeploymentConfig,
    #[cfg(feature = "progress_bars")]
    progress_bars: ProgressBars,
}
impl<'a> Fetcher<'a> {
    pub fn new(proof_keys: &'a ProofKeys, mmr_hasher_config: MMRHasherConfig, mmr_deployment_config: MMRDeploymentConfig) -> Self {
        Self {
            proof_keys,
            mmr_hasher_config,
            mmr_deployment_config,
            #[cfg(feature = "progress_bars")]
            progress_bars: ProgressBars::new(proof_keys),
        }
    }

    async fn collect_evm_headers_proofs(
        &self,
        flattened_keys: &HashSet<FlattenedKey>,
    ) -> Result<HashMap<MmrMeta, Vec<EvmHeader>>, FetcherError> {
        let mut headers_with_mmr = HashMap::default();
        let mut header_fut = futures::stream::iter(flattened_keys.iter().map(|key| {
            EvmProofKeys::fetch_header_proof(
                *self.mmr_deployment_config.get(&key.chain_id).unwrap(),
                key.chain_id,
                key.block_number,
                *self.mmr_hasher_config.get(&key.chain_id).unwrap(),
            )
        }))
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

    pub async fn collect_evm_proofs(&self, chain_id: u128) -> Result<EvmProofs, FetcherError> {
        let mut accounts: HashSet<Account> = HashSet::default();
        let mut storages: HashSet<Storage> = HashSet::default();
        let mut receipts: HashSet<Receipt> = HashSet::default();
        let mut transactions: HashSet<Transaction> = HashSet::default();

        let flattened_keys = self.proof_keys.evm.to_flattened_keys(chain_id);

        // Collect required header proofs for all keys
        let headers_with_mmr = self.collect_evm_headers_proofs(&flattened_keys).await?;

        // Collect account proofs
        let chain_account_keys_iter = self.proof_keys.evm.account_keys.iter().filter(|key| key.chain_id == chain_id);
        let mut account_fut = futures::stream::iter(chain_account_keys_iter.map(EvmProofKeys::fetch_account_proof))
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
        let chain_storage_keys_iter = self.proof_keys.evm.storage_keys.iter().filter(|key| key.chain_id == chain_id);
        let mut storage_fut = futures::stream::iter(chain_storage_keys_iter.map(EvmProofKeys::fetch_storage_proof))
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
        let chain_receipt_keys_iter = self.proof_keys.evm.receipt_keys.iter().filter(|key| key.chain_id == chain_id);
        for key in chain_receipt_keys_iter.clone() {
            if let std::collections::hash_map::Entry::Vacant(entry) = receipt_mpt_handlers.entry(key.block_number) {
                let rpc_url = get_corresponding_rpc_url(key).map_err(|e| FetcherError::InternalError(e.to_string()))?;
                let mut mpt_handler =
                    TxReceiptsMptHandler::new(Url::parse(&rpc_url).unwrap()).map_err(|e| FetcherError::InternalError(e.to_string()))?;

                mpt_handler
                    .build_tx_receipts_tree_from_block(key.block_number)
                    .await
                    .map_err(|e| FetcherError::InternalError(e.to_string()))?;

                entry.insert(mpt_handler);
            }

            #[cfg(feature = "progress_bars")]
            self.progress_bars.evm_receipts.safe_inc();
        }

        receipts.extend(
            chain_receipt_keys_iter
                .map(|key| EvmProofKeys::compute_receipt_proof(key, receipt_mpt_handlers.get_mut(&key.block_number).unwrap()).unwrap()),
        );

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_receipts
            .safe_finish_with_message("evm receipt keys - finished");

        // For each tx block, we need to create a mpt_handler
        let mut tx_mpt_handlers: HashMap<u64, TxsMptHandler> = HashMap::default();
        let chain_tx_keys_iter = self.proof_keys.evm.transaction_keys.iter().filter(|key| key.chain_id == chain_id);
        for key in chain_tx_keys_iter.clone() {
            if let std::collections::hash_map::Entry::Vacant(entry) = tx_mpt_handlers.entry(key.block_number) {
                let rpc_url = get_corresponding_rpc_url(key).map_err(|e| FetcherError::InternalError(e.to_string()))?;
                let mut mpt_handler =
                    TxsMptHandler::new(Url::parse(&rpc_url).unwrap()).map_err(|e| FetcherError::InternalError(e.to_string()))?;

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
            chain_tx_keys_iter
                .map(|key| EvmProofKeys::compute_transaction_proof(key, tx_mpt_handlers.get_mut(&key.block_number).unwrap()).unwrap()),
        );

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .evm_transactions
            .safe_finish_with_message("evm transaction keys - finished");

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
        let mut header_fut = futures::stream::iter(flattened_keys.iter().map(|key| {
            StarknetProofKeys::fetch_header_proof(
                *self.mmr_deployment_config.get(&key.chain_id).unwrap(),
                key.chain_id,
                key.block_number,
                *self.mmr_hasher_config.get(&key.chain_id).unwrap(),
            )
        }))
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

    pub async fn collect_starknet_proofs(&self, chain_id: u128) -> Result<StarknetProofs, FetcherError> {
        let mut storages: HashSet<StarknetStorage> = HashSet::default();

        let flattened_keys = self.proof_keys.starknet.to_flattened_keys(chain_id);

        let headers_with_mmr = self.collect_starknet_headers_proofs(&flattened_keys).await?;

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .starknet_header
            .safe_finish_with_message("starknet header keys - finished");

        // Collect storage proofs
        let chain_storage_keys_iter = self.proof_keys.starknet.storage_keys.iter().filter(|key| key.chain_id == chain_id);
        let mut storage_fut = futures::stream::iter(chain_storage_keys_iter.map(StarknetProofKeys::fetch_storage_proof))
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

    pub async fn collect_unconstrained_data(&self) -> Result<UnconstrainedState, FetcherError> {
        let mut data = HashMap::default();

        // Collect data
        let bytecode_keys_iter = self.proof_keys.unconstrained.bytecode.iter();
        let mut data_fut =
            futures::stream::iter(bytecode_keys_iter.map(|key: &types::keys::evm::account::Key| async move {
                (key.clone(), UnconstrainedProofKeys::fetch_bytecode(key).await)
            }))
            .buffer_unordered(BUFFER_UNORDERED)
            .boxed();

        while let Some::<(types::keys::evm::account::Key, Result<Bytes, FetcherError>)>((key, result)) = data_fut.next().await {
            data.insert(
                Into::<types::keys::evm::account::CairoKey>::into(key).hash(),
                UnconstrainedStateValue::Bytecode(result?),
            );
            #[cfg(feature = "progress_bars")]
            self.progress_bars.unconstrained.safe_inc();
        }

        #[cfg(feature = "progress_bars")]
        self.progress_bars
            .unconstrained
            .safe_finish_with_message("starknet storage keys - finished");

        Ok(UnconstrainedState(data))
    }

    pub async fn collect_state_proofs(&self) -> Result<StateProofs, FetcherError> {
        let state_server_url = std::env::var("INJECTED_STATE_BASE_URL").unwrap_or_else(|_| "http://localhost:3000".to_string());
        let client = reqwest::Client::new();

        let actions = self.proof_keys.injected_state.clone();
        let mut result = StateProofs::new();

        for (_trie_label, actions) in actions.into_iter() {
            let request_payload = GetStateProofsRequest { actions };

            let response = client
                .post(format!("{}/get_state_proofs", state_server_url))
                .header("content-type", "application/json")
                .json(&request_payload)
                .send()
                .await?;

            let response_body: GetStateProofsResponse = response.json().await?;
            let state_proofs = response_body.state_proofs;
            result.extend(state_proofs);
        }

        Ok(result)
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
    syscall_handler: SyscallHandler<
        evm::CallContractHandler,
        starknet::CallContractHandler,
        injected_state::CallContractHandler,
        unconstrained::CallContractHandler,
    >,
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

    // Process injected state keys
    for (root_hash, actions) in syscall_handler.call_contract_handler.injected_state_call_contract_handler.key_set {
        proof_keys.injected_state.insert(root_hash, actions);
    }

    for key in syscall_handler.call_contract_handler.unconstrained_call_contract_handler.key_set {
        match key {
            unconstrained::DryRunKey::Bytecode(value) => proof_keys.unconstrained.bytecode.insert(value),
        };
    }

    Ok(proof_keys)
}

/// Checks if a block is contained within any of the inclusive ranges.
fn in_ranges(ranges: &[RangeInclusive<u64>], block: u64) -> bool {
    ranges.iter().any(|range| range.contains(&block))
}

/// Checks if all required blocks are covered by the given ranges.
fn covers_all(ranges: &[RangeInclusive<u64>], blocks: &HashSet<u64>) -> bool {
    blocks.iter().all(|b| in_ranges(ranges, *b))
}

fn required_chain_ids_for_evm(proof_keys: &ProofKeys) -> HashSet<u128> {
    proof_keys
        .evm
        .header_keys
        .iter()
        .map(|f| f.chain_id)
        .chain(proof_keys.evm.account_keys.iter().map(|f| f.chain_id))
        .chain(proof_keys.evm.storage_keys.iter().map(|f| f.chain_id))
        .chain(proof_keys.evm.receipt_keys.iter().map(|f| f.chain_id))
        .chain(proof_keys.evm.transaction_keys.iter().map(|f| f.chain_id))
        .collect()
}

fn required_chain_ids_for_starknet(proof_keys: &ProofKeys) -> HashSet<u128> {
    proof_keys
        .starknet
        .header_keys
        .iter()
        .map(|f| f.chain_id)
        .chain(proof_keys.starknet.storage_keys.iter().map(|f| f.chain_id))
        .collect()
}

fn required_evm_blocks(proof_keys: &ProofKeys, chain_id: u128) -> HashSet<u64> {
    proof_keys
        .evm
        .to_flattened_keys(chain_id)
        .into_iter()
        .map(|fk| fk.block_number)
        .collect()
}

fn required_starknet_blocks(proof_keys: &ProofKeys, chain_id: u128) -> HashSet<u64> {
    proof_keys
        .starknet
        .to_flattened_keys(chain_id)
        .into_iter()
        .map(|fk| fk.block_number)
        .collect()
}

/// Implements the core strategy: Prefer Poseidon, then Keccak, else Error.
fn determine_hashing_function(ranges: &FunctionsRanges, required_blocks: &HashSet<u64>) -> Result<HashingFunction, FetcherError> {
    if covers_all(&ranges.poseidon, required_blocks) {
        Ok(HashingFunction::Poseidon)
    } else if covers_all(&ranges.keccak, required_blocks) {
        Ok(HashingFunction::Keccak)
    } else {
        Err(FetcherError::InternalError(
            "given block not available on indexer for both keccak and poseidon hashing functions".to_string(),
        ))
    }
}

pub async fn infer_mmr_sources_from_indexer(proof_keys: &ProofKeys) -> Result<HashMap<u128, HashingFunction>, FetcherError> {
    let ranges = Indexer::default().get_all_ranges_accumulated_per_chain().await?;
    let default_ranges = FunctionsRanges::default();

    // Process EVM chains.
    let evm_iter = required_chain_ids_for_evm(proof_keys)
        .into_iter()
        .filter_map(|chain_id| {
            // Get blocks; skip chain if no blocks are required.
            let required_blocks = required_evm_blocks(proof_keys, chain_id);
            if required_blocks.is_empty() {
                None
            } else {
                Some((chain_id, required_blocks))
            }
        })
        .map(|(chain_id, required_blocks)| {
            let pair_ranges = ranges.get(&chain_id).and_then(|m| m.get(&chain_id)).unwrap_or(&default_ranges);
            determine_hashing_function(pair_ranges, &required_blocks).map(|func| (chain_id, func))
        });

    // Process Starknet chains.
    let starknet_iter = required_chain_ids_for_starknet(proof_keys)
        .into_iter()
        .filter_map(|chain_id| {
            // Get blocks; skip chain if no blocks are required.
            let required_blocks = required_starknet_blocks(proof_keys, chain_id);
            if required_blocks.is_empty() {
                None
            } else {
                Some((chain_id, required_blocks))
            }
        })
        .map(|(chain_id, required_blocks)| {
            let pair_ranges = ranges.get(&chain_id).and_then(|m| m.get(&chain_id)).unwrap_or(&default_ranges);
            determine_hashing_function(pair_ranges, &required_blocks).map(|func| (chain_id, func))
        });

    evm_iter.chain(starknet_iter).collect()
}
