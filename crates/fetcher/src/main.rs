#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use alloy::hex::FromHexError;
use clap::{Parser, ValueHint};
use dry_hint_processor::syscall_handler::evm::{self, SyscallHandler};
use futures::{FutureExt, StreamExt};
use indexer::types::IndexerError;
use proof_keys::ProofKeys;
use std::{collections::HashSet, fs, num::ParseIntError, path::PathBuf};
use thiserror::Error;
use types::proofs::{account::Account, storage::Storage, HeaderMmrMeta, Proofs};

pub mod proof_keys;

const BUFFER_UNORDERED: usize = 10;

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

    let input_file = fs::read(args.filename)?;
    let syscall_handler = serde_json::from_slice::<SyscallHandler>(&input_file)?;

    let mut proof_keys = ProofKeys::default();
    for key in syscall_handler.call_contract_handler.key_set {
        match key {
            evm::DryRunKey::Account(value) => {
                proof_keys.account_keys.insert(value);
            }
            evm::DryRunKey::Header(value) => {
                proof_keys.header_keys.insert(value);
            }
            evm::DryRunKey::Storage(value) => {
                proof_keys.storage_keys.insert(value);
            }
        }
    }

    let mut headers_with_mmr: HashSet<HeaderMmrMeta> = HashSet::default();

    let mut headers_with_mmr_fut = futures::stream::iter(proof_keys.header_keys.iter().map(ProofKeys::fetch_header_proof).map(|f| f.boxed_local()))
        .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok(item)) = headers_with_mmr_fut.next().await {
        headers_with_mmr.insert(item);
    }

    let mut accounts: HashSet<Account> = HashSet::default();

    let mut accounts_fut = futures::stream::iter(
        proof_keys
            .account_keys
            .iter()
            .map(ProofKeys::fetch_account_proof)
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok((header_with_mmr, account))) = accounts_fut.next().await {
        headers_with_mmr.insert(header_with_mmr);
        accounts.insert(account);
    }

    let mut storages: HashSet<Storage> = HashSet::default();

    let mut storages_fut = futures::stream::iter(
        proof_keys
            .storage_keys
            .iter()
            .map(ProofKeys::fetch_storage_proof)
            .map(|f| f.boxed_local()),
    )
    .buffer_unordered(BUFFER_UNORDERED);

    while let Some(Ok((header_with_mmr, account, storage))) = storages_fut.next().await {
        headers_with_mmr.insert(header_with_mmr.clone());
        accounts.insert(account);
        storages.insert(storage);
    }

    let proofs = Proofs {
        headers_with_mmr: headers_with_mmr.into_iter().collect(),
        accounts: accounts.into_iter().collect(),
        storages: storages.into_iter().collect(),
        ..Default::default()
    };

    fs::write(args.program_output, serde_json::to_vec(&proofs).map_err(|e| FetcherError::IO(e.into()))?)?;

    Ok(())
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
}
