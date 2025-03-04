#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::fs;

use alloy as _;
use alloy_rlp as _;
use cairo_vm as _;
use clap::Parser;
use dry_hint_processor::syscall_handler::{evm, starknet};
use eth_trie_proofs as _;
use fetcher::{parse_syscall_handler, Args, Fetcher};
use futures as _;
use indexer as _;
use indicatif as _;
use reqwest as _;
use starknet_types_core as _;
use syscall_handler::SyscallHandler;
use thiserror as _;
use types::ChainProofs;

#[tokio::main]
async fn main() -> Result<(), fetcher::FetcherError> {
    dotenvy::dotenv().ok();
    let args = Args::try_parse_from(std::env::args()).map_err(fetcher::FetcherError::Args)?;
    let input_file = fs::read(&args.inputs)?;

    let syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler> = serde_json::from_slice(&input_file)?;
    let proof_keys = parse_syscall_handler(syscall_handler)?;

    let fetcher = Fetcher::new(&proof_keys);
    let (evm_proofs, starknet_proofs) = tokio::try_join!(fetcher.collect_evm_proofs(), fetcher.collect_starknet_proofs())?;
    let chain_proofs = vec![
        ChainProofs::EthereumSepolia(evm_proofs),
        ChainProofs::StarknetSepolia(starknet_proofs),
    ];

    fs::write(
        args.output,
        serde_json::to_string_pretty(&chain_proofs)
            .map_err(|e| fetcher::FetcherError::IO(e.into()))?
            .as_bytes(),
    )?;

    Ok(())
}
