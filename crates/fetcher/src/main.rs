#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::fs;

use alloy as _;
use alloy_rlp as _;
use cairo_vm as _;
use clap::Parser;
use dry_hint_processor::syscall_handler::{evm, injected_state, starknet};
use eth_trie_proofs as _;
use fetcher::{infer_mmr_sources_from_indexer, parse_proofs_fetcher_config, parse_syscall_handler, Args, Fetcher};
use futures as _;
use indexer_client as _;
use indicatif as _;
use reqwest as _;
use starknet_types_core as _;
use state_server as _;
use syscall_handler::SyscallHandler;
use thiserror as _;
use types::{
    ChainProofs, ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID,
    STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
};

#[tokio::main]
async fn main() -> Result<(), fetcher::FetcherError> {
    dotenvy::dotenv().ok();
    let args = Args::try_parse_from(std::env::args()).map_err(fetcher::FetcherError::Args)?;
    let input_file = fs::read(&args.inputs)?;

    let syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler> =
        serde_json::from_slice(&input_file)?;
    let proof_keys = parse_syscall_handler(syscall_handler)?;

    let per_chain_mmr = if let Some(path) = args.proofs_fetcher_config.as_ref() {
        parse_proofs_fetcher_config(path)?
    } else {
        infer_mmr_sources_from_indexer(&proof_keys, args.deployed_on_chain).await?
    };

    let fetcher = Fetcher::new_with_mmr_sources_map(&proof_keys, per_chain_mmr, args.deployed_on_chain);
    let (
        eth_proofs_mainnet,
        eth_proofs_sepolia,
        starknet_proofs_mainnet,
        starknet_proofs_sepolia,
        optimism_proofs_mainnet,
        optimism_proofs_sepolia,
        state_proofs,
    ) = tokio::try_join!(
        fetcher.collect_evm_proofs(ETHEREUM_MAINNET_CHAIN_ID),
        fetcher.collect_evm_proofs(ETHEREUM_TESTNET_CHAIN_ID),
        fetcher.collect_starknet_proofs(STARKNET_MAINNET_CHAIN_ID),
        fetcher.collect_starknet_proofs(STARKNET_TESTNET_CHAIN_ID),
        fetcher.collect_evm_proofs(OPTIMISM_MAINNET_CHAIN_ID),
        fetcher.collect_evm_proofs(OPTIMISM_TESTNET_CHAIN_ID),
        fetcher.collect_state_proofs(),
    )?;
    let chain_proofs = vec![
        ChainProofs::EthereumMainnet(eth_proofs_mainnet),
        ChainProofs::EthereumSepolia(eth_proofs_sepolia),
        ChainProofs::StarknetMainnet(starknet_proofs_mainnet),
        ChainProofs::StarknetSepolia(starknet_proofs_sepolia),
        ChainProofs::OptimismMainnet(optimism_proofs_mainnet),
        ChainProofs::OptimismSepolia(optimism_proofs_sepolia),
    ];

    fs::write(
        args.output,
        serde_json::to_string_pretty(&(chain_proofs, state_proofs))
            .map_err(|e| fetcher::FetcherError::IO(e.into()))?
            .as_bytes(),
    )?;

    Ok(())
}
