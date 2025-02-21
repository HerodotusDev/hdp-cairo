#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use cairo_vm as _;
use clap::Parser;
use sound_hint_processor as _;
use sound_run::Args;
use tracing::info;
use types::{error::Error, param::Param, CasmContractClass, ChainProofs, HDPInput};

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt::init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
    let params: Vec<Param> = if let Some(input_path) = args.inputs {
        serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };
    let chain_proofs: Vec<ChainProofs> = serde_json::from_slice(&std::fs::read(args.proofs).map_err(Error::IO)?)?;

    let (pie, output) = sound_run::run(HDPInput {
        chain_proofs,
        compiled_class,
        params,
    })?;

    if args.print_output {
        info!("{:#?}", output);
    }

    if let Some(ref file_name) = args.cairo_pie_output {
        pie.write_zip_file(file_name)?
    }

    Ok(())
}
