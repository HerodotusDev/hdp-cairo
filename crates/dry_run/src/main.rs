#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use cairo_vm as _;
use clap::Parser;
use dry_hint_processor::syscall_handler::{evm, starknet};
use dry_run::Args;
use hints as _;
use syscall_handler::SyscallHandler;
use tracing::info;
use types::{error::Error, param::Param, CasmContractClass, HDPDryRunInput};

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    println!("Starting dry run...");
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt::init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    println!("Reading compiled module: {:?}", args.compiled_module);
    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
    println!("Compiled module read successfully");
    let params: Vec<Param> = if let Some(input_path) = args.inputs {
        serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };
    println!("Params: {:?}", params);

    let (syscall_handler, output) = dry_run::run(args.program, HDPDryRunInput { compiled_class, params })?;

    if args.print_output {
        info!("{:#?}", output);
    }

    std::fs::write(
        args.output,
        serde_json::to_vec::<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>(&syscall_handler)
            .map_err(|e| Error::IO(e.into()))?,
    )
    .map_err(Error::IO)?;

    Ok(())
}
