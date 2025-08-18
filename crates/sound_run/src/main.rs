#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::path::PathBuf;

use cairo_vm as _;
use clap::Parser;
use sound_hint_processor as _;
use sound_run::{Args, HDP_COMPILED_JSON};
use tracing as _;
use tracing_subscriber::EnvFilter;
use types::{error::Error, param::Param, CasmContractClass, HDPInput, ProofsData};

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
    let params: Vec<Param> = if let Some(input_path) = args.inputs {
        serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };

    let proofs_data: ProofsData = serde_json::from_slice(&std::fs::read(args.proofs).map_err(Error::IO)?)?;

    let (pie, output) = sound_run::run(
        args.program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON)),
        HDPInput {
            chain_proofs: proofs_data.chain_proofs,
            compiled_class,
            params,
            state_proofs: proofs_data.state_proofs,
        },
    )?;

    if args.print_output {
        println!("{:#?}", output);
    }

    if let Some(ref file_name) = args.cairo_pie_output {
        pie.write_zip_file(file_name, true)?
    }

    Ok(())
}
