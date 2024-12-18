#![forbid(unsafe_code)]
#![allow(async_fn_in_trait)]
use clap::{Parser, ValueHint};
use dry_hint_processor::syscall_handler::evm::{self, SyscallHandler};
use fetcher::{proof_keys::ProofKeys, FetcherError};
use std::{collections::HashSet, fs, path::PathBuf};
use types::proofs::{account::Account, storage::Storage, HeaderMmrMeta, Proofs};

pub mod proof_keys;

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[clap(value_parser, value_hint=ValueHint::FilePath)]
    filename: PathBuf,
    #[structopt(long = "program_output")]
    program_output: PathBuf,
}

fn main() -> Result<(), FetcherError> {
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

    let mut headers_with_mmr = proof_keys
        .header_keys
        .iter()
        .map(ProofKeys::fetch_header_proof)
        .collect::<Result<HashSet<HeaderMmrMeta>, FetcherError>>()?;

    let mut accounts: HashSet<Account> = HashSet::default();

    for (header_with_mmr, account) in proof_keys
        .account_keys
        .iter()
        .map(ProofKeys::fetch_account_proof)
        .collect::<Result<Vec<(HeaderMmrMeta, Account)>, FetcherError>>()?
        .into_iter()
    {
        headers_with_mmr.insert(header_with_mmr);
        accounts.insert(account);
    }

    let mut storages: HashSet<Storage> = HashSet::default();

    for (header_with_mmr, account, storage) in proof_keys
        .storage_keys
        .iter()
        .map(ProofKeys::fetch_storage_proof)
        .collect::<Result<Vec<(HeaderMmrMeta, Account, Storage)>, FetcherError>>()?
        .into_iter()
    {
        headers_with_mmr.insert(header_with_mmr);
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
