#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::path::PathBuf;

use cairo_vm as _;
use clap::Parser;
use dry_hint_processor::syscall_handler::{evm, injected_state, starknet};
use dry_run::{Args, DRY_RUN_COMPILED_JSON};
use hints as _;
use syscall_handler::SyscallHandler;
use tracing as _;
use tracing_subscriber::EnvFilter;
use types::{error::Error, param::Param, CasmContractClass, HDPDryRunInput, InjectedState};

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
    let params: Vec<Param> = if let Some(path) = args.inputs {
        serde_json::from_slice(&std::fs::read(path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };
    let injected_state: InjectedState = if let Some(path) = args.injected_state {
        serde_json::from_slice(&std::fs::read(path).map_err(Error::IO)?)?
    } else {
        InjectedState::default()
    };

    let (syscall_handler, output) = dry_run::run(
        args.program.unwrap_or(PathBuf::from(DRY_RUN_COMPILED_JSON)),
        HDPDryRunInput {
            compiled_class,
            params,
            injected_state,
        },
    )?;

    if args.print_output {
        println!("{:#?}", output);
    }

    std::fs::write(
        args.output,
        serde_json::to_vec::<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>>(
            &syscall_handler,
        )
        .map_err(|e| Error::IO(e.into()))?,
    )
    .map_err(Error::IO)?;

    Ok(())
}
