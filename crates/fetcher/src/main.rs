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
        evm::{account::Account, storage::Storage}, header::Header, mmr::MmrMeta, starknet::GetProofOutput, HeaderMmrMeta
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

#[tokio::main]
async fn main() -> Result<(), FetcherError> {
    let args = Args::try_parse_from(std::env::args()).map_err(FetcherError::Args)?;

    let multi_progress = MultiProgress::new();
    let progress_style = ProgressStyle::with_template("[{elapsed_precise}] [{bar:40}] {pos}/{len} {msg}")
        .unwrap()
        .progress_chars("=> ");

    let input_file = fs::read(args.filename)?;
    let syscall_handler = serde_json::from_slice::<SyscallHandler>(&input_file)?;
    println!("{:?}", syscall_handler);

    let mut proof_keys = ProofKeys::default();
    for key in syscall_handler.call_contract_handler.evm_call_contract_handler.key_set {
        match key {
            evm::DryRunKey::Account(value) => {
                proof_keys.evm.account_keys.insert(value);
            }
            evm::DryRunKey::Header(value) => {
                proof_keys.evm.header_keys.insert(value);
            }
            evm::DryRunKey::Storage(value) => {
                proof_keys.evm.storage_keys.insert(value);
            }
        }
    }

    for key in syscall_handler.call_contract_handler.starknet_call_contract_handler.key_set {
        println!("{:?}", key);
        match key {
            starknet::DryRunKey::Header(value) => {
                proof_keys.starknet.header_keys.insert(value);
            }
            starknet::DryRunKey::Storage(value) => {
                proof_keys.starknet.storage_keys.insert(value);
            }
        }
    }

    let pb_evm_header_keys = multi_progress.add(ProgressBar::new(proof_keys.evm.header_keys.len() as u64));
    let pb_evm_account_keys = multi_progress.add(ProgressBar::new(proof_keys.evm.account_keys.len() as u64));
    let pb_evm_storage_keys = multi_progress.add(ProgressBar::new(proof_keys.evm.storage_keys.len() as u64));    
    let pb_starknet_header_keys = multi_progress.add(ProgressBar::new(proof_keys.starknet.header_keys.len() as u64));
    let pb_starknet_storage_keys = multi_progress.add(ProgressBar::new(proof_keys.starknet.storage_keys.len() as u64));
    
    pb_evm_header_keys.set_style(progress_style.clone());
    pb_evm_header_keys.set_message("evm_header_keys");
    pb_evm_account_keys.set_style(progress_style.clone());
    pb_evm_account_keys.set_message("evm_account_keys");
    pb_evm_storage_keys.set_style(progress_style.clone());
    pb_evm_storage_keys.set_message("evm_storage_keys");
    pb_starknet_header_keys.set_style(progress_style.clone());
    pb_starknet_header_keys.set_message("starknet_header_keys");
    pb_starknet_storage_keys.set_style(progress_style);
    pb_starknet_storage_keys.set_message("starknet_storage_keys");

    let mut evm_headers_with_mmr: HashMap<MmrMeta, Vec<Header>> = HashMap::default();
    let mut evm_headers_with_mmr_fut = futures::stream::iter(
        proof_keys
            .evm
            .header_keys
            .iter()
            .map(|key| ProofKeys::fetch_header_proof(key.chain_id, key.block_number))
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok(item)) = evm_headers_with_mmr_fut.next().await {
        evm_headers_with_mmr
            .entry(item.mmr_meta)
            .and_modify(|headers| headers.extend(item.headers.clone()))
            .or_insert(item.headers);
        pb_evm_header_keys.inc(1);
    }

    let mut evm_accounts: HashSet<Account> = HashSet::default();
    let mut evm_accounts_fut = futures::stream::iter(
        proof_keys
            .evm
            .account_keys
            .iter()
            .map(EvmProofKeys::fetch_account_proof)
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok((header_with_mmr, account))) = evm_accounts_fut.next().await {
        evm_headers_with_mmr
            .entry(header_with_mmr.mmr_meta)
            .and_modify(|headers| headers.extend(header_with_mmr.headers.clone()))
            .or_insert(header_with_mmr.headers);
        evm_accounts.insert(account);
        pb_evm_account_keys.inc(1);
    }

    let mut evm_storages: HashSet<Storage> = HashSet::default();
    let mut evm_storages_fut = futures::stream::iter(
        proof_keys
            .evm
            .storage_keys
            .iter()
            .map(EvmProofKeys::fetch_storage_proof)
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok((header_with_mmr, account, storage))) = evm_storages_fut.next().await {
        evm_headers_with_mmr
            .entry(header_with_mmr.mmr_meta)
            .and_modify(|headers| headers.extend(header_with_mmr.headers.clone()))
            .or_insert(header_with_mmr.headers);
        evm_accounts.insert(account);
        evm_storages.insert(storage);
        pb_evm_storage_keys.inc(1);
    }

    // Remove the duplicates from the headers
    let evm_headers: Vec<HeaderMmrMeta> = evm_headers_with_mmr
        .into_iter()
        .map(|(mmr_meta, headers)| {
            let unique_headers: Vec<_> = headers.into_iter().collect::<HashSet<_>>().into_iter().collect();
            HeaderMmrMeta {
                headers: unique_headers,
                mmr_meta,
            }
        })
        .collect();

    let evm_proofs = EvmProofs { 
        headers_with_mmr: evm_headers,
        accounts: evm_accounts.into_iter().collect(),
        storages: evm_storages.into_iter().collect(),
        ..Default::default()
    };

    let mut starknet_headers_with_mmr: HashMap<MmrMeta, Vec<Header>> = HashMap::default();
    let mut starknet_headers_with_mmr_fut = futures::stream::iter(
        proof_keys
            .starknet
            .header_keys
            .iter()
            .map(|key| ProofKeys::fetch_header_proof(key.chain_id, key.block_number))
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok(item)) = starknet_headers_with_mmr_fut.next().await {
        starknet_headers_with_mmr
            .entry(item.mmr_meta)
            .and_modify(|headers| headers.extend(item.headers.clone()))
            .or_insert(item.headers);
        pb_starknet_header_keys.inc(1);
    }

    let mut starknet_storages: HashSet<GetProofOutput> = HashSet::default();
    let mut storages_fut = futures::stream::iter(
        proof_keys
            .starknet
            .storage_keys
            .iter()
            .map(StarknetProofKeys::fetch_storage_proof)
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok((header_with_mmr, storage))) = storages_fut.next().await {
        starknet_headers_with_mmr
            .entry(header_with_mmr.mmr_meta)
            .and_modify(|headers| headers.extend(header_with_mmr.headers.clone()))
            .or_insert(header_with_mmr.headers);
        starknet_storages.insert(storage);
        pb_starknet_storage_keys.inc(1);
    }

    let starknet_headers: Vec<HeaderMmrMeta> = starknet_headers_with_mmr
        .into_iter()
        .map(|(mmr_meta, headers)| {
            let unique_headers: Vec<_> = headers.into_iter().collect::<HashSet<_>>().into_iter().collect();
            HeaderMmrMeta {
                headers: unique_headers,
                mmr_meta,
            }
        })
        .collect();

    let starknet_proofs = StarknetProofs {
        headers_with_mmr: starknet_headers,
        storages: starknet_storages.into_iter().collect(),
    };


    let chain_proofs = vec![
        ChainProofs::EthereumSepolia(evm_proofs), 
        ChainProofs::StarknetSepolia(starknet_proofs)
    ];
    println!("{:?}", chain_proofs);

    fs::write(
        args.program_output,
        serde_json::to_vec(&chain_proofs).map_err(|e| FetcherError::IO(e.into()))?,
    )?;

    Ok(())
}
