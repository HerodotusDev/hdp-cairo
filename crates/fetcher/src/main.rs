#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use clap::{Parser, ValueHint};
use dry_hint_processor::syscall_handler::{evm, starknet, SyscallHandler};
use fetcher::FetcherError;
use futures::{FutureExt, StreamExt};
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use proof_keys::ProofKeys;
use std::{
    collections::{HashMap, HashSet},
    fs,
    path::PathBuf,
};
use thiserror as _;
use types::{
    proofs::{
        header::Header, 
        mmr::MmrMeta, 
        HeaderMmrMeta,
        evm::{
            account::Account,
            storage::Storage
        },
        starknet::GetProofOutput
    },
    ChainProofs,
};

use types::proofs::evm::Proofs as EvmProofs;
use types::proofs::starknet::Proofs as StarknetProofs;
mod proof_keys;

use proof_keys::evm::ProofKeys as EvmProofKeys;
use proof_keys::starknet::ProofKeys as StarknetProofKeys;
const BUFFER_UNORDERED: usize = 50;

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[clap(value_parser, value_hint=ValueHint::FilePath)]
    filename: PathBuf,
    #[structopt(long = "program_output")]
    program_output: PathBuf,
}
struct ProofProgress {
    evm_header: ProgressBar,
    evm_account: ProgressBar,
    evm_storage: ProgressBar,
    starknet_header: ProgressBar,
    starknet_storage: ProgressBar,
}

impl ProofProgress {
    fn new(proof_keys: &ProofKeys) -> Self {
        let multi_progress = MultiProgress::new();
        let style = ProgressStyle::with_template("[{elapsed_precise}] [{bar:40}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("=> ");

        let bars = [
            (proof_keys.evm.header_keys.len(), "evm_header_keys"),
            (proof_keys.evm.account_keys.len(), "evm_account_keys"),
            (proof_keys.evm.storage_keys.len(), "evm_storage_keys"),
            (proof_keys.starknet.header_keys.len(), "starknet_header_keys"),
            (proof_keys.starknet.storage_keys.len(), "starknet_storage_keys"),
        ].map(|(len, msg)| {
            let pb = multi_progress.add(ProgressBar::new(len as u64));
            pb.set_style(style.clone());
            pb.set_message(msg);
            pb
        });

        Self {
            multi_progress,
            evm_header: bars[0].clone(),
            evm_account: bars[1].clone(),
            evm_storage: bars[2].clone(),
            starknet_header: bars[3].clone(),
            starknet_storage: bars[4].clone(),
        }
    }

    fn finish(self) {
        self.evm_header.finish_with_message("EVM Header Keys - Done!");
        self.evm_account.finish_with_message("EVM Account Keys - Done!");
        self.evm_storage.finish_with_message("EVM Storage Keys - Done!");
        self.starknet_header.finish_with_message("Starknet Header Keys - Done!");
        self.starknet_storage.finish_with_message("Starknet Storage Keys - Done!");
    }
}

async fn collect_evm_proofs(
    proof_keys: &EvmProofKeys,
    progress: &ProofProgress,
) -> Result<EvmProofs, FetcherError> {
    let mut headers_with_mmr = HashMap::default();
    let mut accounts: HashSet<Account> = HashSet::default();
    let mut storages: HashSet<Storage> = HashSet::default();

    // Collect header proofs
    let mut header_fut = futures::stream::iter(
        proof_keys.header_keys.iter()
            .map(|key| ProofKeys::fetch_header_proof(key.chain_id, key.block_number))
            .map(|f| f.boxed_local()),
    ).buffer_unordered(BUFFER_UNORDERED);

    while let Some(result) = header_fut.next().await {
        let item = result?;
        headers_with_mmr
            .entry(item.mmr_meta)
            .and_modify(|headers: &mut Vec<Header>| headers.extend(item.headers.clone()))
            .or_insert(item.headers);
        progress.evm_header.inc(1);
    }

    // Collect account proofs
    let mut account_fut = futures::stream::iter(
        proof_keys.account_keys.iter()
            .map(EvmProofKeys::fetch_account_proof)
            .map(|f| f.boxed_local()),
    ).buffer_unordered(BUFFER_UNORDERED);

    while let Some(result) = account_fut.next().await {
        let (header_with_mmr, account) = result?;
        headers_with_mmr
            .entry(header_with_mmr.mmr_meta)
            .and_modify(|headers: &mut Vec<Header>| headers.extend(header_with_mmr.headers.clone()))
            .or_insert(header_with_mmr.headers);
        accounts.insert(account);
        progress.evm_account.inc(1);
    }

    // Collect storage proofs
    let mut storage_fut = futures::stream::iter(
        proof_keys.storage_keys.iter()
            .map(EvmProofKeys::fetch_storage_proof)
            .map(|f| f.boxed_local()),
    ).buffer_unordered(BUFFER_UNORDERED);

    while let Some(result) = storage_fut.next().await {
        let (header_with_mmr, account, storage) = result?;
        headers_with_mmr
            .entry(header_with_mmr.mmr_meta)
            .and_modify(|headers: &mut Vec<Header>| headers.extend(header_with_mmr.headers.clone()))
            .or_insert(header_with_mmr.headers);
        accounts.insert(account);
        storages.insert(storage);
        progress.evm_storage.inc(1);
    }

    Ok(EvmProofs {
        headers_with_mmr: process_headers(headers_with_mmr),
        accounts: accounts.into_iter().collect(),
        storages: storages.into_iter().collect(),
        ..Default::default()
    })
}

async fn collect_starknet_proofs(
    proof_keys: &StarknetProofKeys,
    progress: &ProofProgress,
) -> Result<StarknetProofs, FetcherError> {
    let mut headers_with_mmr = HashMap::default();
    let mut storages: HashSet<GetProofOutput> = HashSet::default();

    // Collect header proofs
    let mut header_fut = futures::stream::iter(
        proof_keys.header_keys.iter()
            .map(|key| ProofKeys::fetch_header_proof(key.chain_id, key.block_number))
            .map(|f| f.boxed_local()),
    ).buffer_unordered(BUFFER_UNORDERED);

    while let Some(result) = header_fut.next().await {
        let item = result?;
        headers_with_mmr
            .entry(item.mmr_meta)
            .and_modify(|headers: &mut Vec<Header>| headers.extend(item.headers.clone()))
            .or_insert(item.headers);
        progress.starknet_header.inc(1);
    }

    // Collect storage proofs
    let mut storage_fut = futures::stream::iter(
        proof_keys.storage_keys.iter()
            .map(StarknetProofKeys::fetch_storage_proof)
            .map(|f| f.boxed_local()),
    ).buffer_unordered(BUFFER_UNORDERED);

    while let Some(result) = storage_fut.next().await {
        let (header_with_mmr, storage) = result?;
        headers_with_mmr
            .entry(header_with_mmr.mmr_meta)
            .and_modify(|headers: &mut Vec<Header>| headers.extend(header_with_mmr.headers.clone()))
            .or_insert(header_with_mmr.headers);
        storages.insert(storage);
        progress.starknet_storage.inc(1);
    }

    Ok(StarknetProofs {
        headers_with_mmr: process_headers(headers_with_mmr),
        storages: storages.into_iter().collect(),
    })
}

fn process_headers(headers_with_mmr: HashMap<MmrMeta, Vec<Header>>) -> Vec<HeaderMmrMeta> {
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

fn parse_syscall_handler(input_file: &[u8]) -> Result<ProofKeys, FetcherError> {
    let syscall_handler = serde_json::from_slice::<SyscallHandler>(input_file)?;
    let mut proof_keys = ProofKeys::default();

    // Process EVM keys
    for key in syscall_handler.call_contract_handler.evm_call_contract_handler.key_set {
        match key {
            evm::DryRunKey::Account(value) => proof_keys.evm.account_keys.insert(value),
            evm::DryRunKey::Header(value) => proof_keys.evm.header_keys.insert(value),
            evm::DryRunKey::Storage(value) => proof_keys.evm.storage_keys.insert(value),
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

#[tokio::main]
async fn main() -> Result<(), FetcherError> {
    let args = Args::try_parse_from(std::env::args()).map_err(FetcherError::Args)?;
    let input_file = fs::read(&args.filename)?;
    let proof_keys = parse_syscall_handler(&input_file)?;
    
    let progress = ProofProgress::new(&proof_keys);
    
    let (evm_proofs, starknet_proofs) = tokio::try_join!(
        collect_evm_proofs(&proof_keys.evm, &progress),
        collect_starknet_proofs(&proof_keys.starknet, &progress)
    )?;

    let chain_proofs = vec![
        ChainProofs::EthereumSepolia(evm_proofs),
        ChainProofs::StarknetSepolia(starknet_proofs)
    ];

    progress.finish();

    fs::write(
        args.program_output,
        serde_json::to_string_pretty(&chain_proofs).map_err(|e| FetcherError::IO(e.into()))?.as_bytes(),
    )?;

    Ok(())
}