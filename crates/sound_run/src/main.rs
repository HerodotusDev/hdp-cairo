#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use bytemuck as _;
use cairo_vm as _;
use clap::Parser;
use serde_json as _;
use sound_hint_processor as _;
use sound_run::Args;
use stwo_cairo_adapter as _;
use tracing as _;
use tracing_subscriber::EnvFilter;
use types::error::Error;

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    sound_run::run_with_args(args).await
}
