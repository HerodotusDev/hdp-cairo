#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use alloy as _;
use alloy_rlp as _;
use cairo_vm as _;
use clap::Parser;
use dry_hint_processor as _;
use eth_trie_proofs as _;
use fetcher::{Args, FetcherError};
use futures as _;
use indexer_client::{self as _};
use indicatif as _;
use reqwest as _;
use serde_json as _;
use starknet_types_core as _;
use state_server as _;
use syscall_handler as _;
use thiserror as _;
use tracing as _;
use tracing_subscriber::EnvFilter;
use types as _;

#[tokio::main]
async fn main() -> Result<(), FetcherError> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let args = Args::try_parse_from(std::env::args()).map_err(FetcherError::Args)?;

    fetcher::run_with_args(args).await
}
