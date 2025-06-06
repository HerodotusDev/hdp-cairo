#![allow(async_fn_in_trait)]
#![forbid(unsafe_code)]
#![warn(unused_crate_dependencies)]
#![warn(unused_extern_crates)]

use std::{io, path::Path};

use bincode as _;
use cairo_vm::{
    self as _,
    air_public_input::PublicInputError,
    cairo_run,
    vm::errors::{cairo_run_errors::CairoRunError, trace_errors::TraceError},
};
use clap::Parser;
use sound_hint_processor as _;
use sound_run::{Args, FileWriter};
use tracing as _;
use tracing_subscriber::EnvFilter;
use types::{error::Error, param::Param, CasmContractClass, ChainProofs, HDPInput};

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(&args.compiled_module).map_err(Error::IO)?)?;
    let params: Vec<Param> = if let Some(input_path) = &args.inputs {
        serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };
    let chain_proofs: Vec<ChainProofs> = serde_json::from_slice(&std::fs::read(&args.proofs).map_err(Error::IO)?)?;

    let (cairo_runner, output) = sound_run::run(
        &args,
        HDPInput {
            chain_proofs,
            compiled_class,
            params,
        },
    )?;

    if args.print_output {
        println!("{:#?}", output);
    }

    if let Some(ref trace_path) = args.trace_file {
        let relocated_trace = cairo_runner
            .relocated_trace
            .as_ref()
            .ok_or(Error::Trace(TraceError::TraceNotRelocated))?;

        let trace_file = std::fs::File::create(trace_path)?;
        let mut trace_writer = FileWriter::new(io::BufWriter::with_capacity(3 * 1024 * 1024, trace_file));

        cairo_run::write_encoded_trace(relocated_trace, &mut trace_writer)?;
        trace_writer.flush()?;
    }

    if let Some(ref memory_path) = args.memory_file {
        let memory_file = std::fs::File::create(memory_path)?;
        let mut memory_writer = FileWriter::new(io::BufWriter::with_capacity(5 * 1024 * 1024, memory_file));

        cairo_run::write_encoded_memory(&cairo_runner.relocated_memory, &mut memory_writer)?;
        memory_writer.flush()?;
    }

    if let Some(file_path) = &args.air_public_input {
        let json = cairo_runner.get_air_public_input()?.serialize_json()?;
        std::fs::write(file_path, json)?;
    }

    if let (Some(file_path), Some(ref trace_file), Some(ref memory_file)) = (&args.air_private_input, &args.trace_file, &args.memory_file) {
        // Get absolute paths of trace_file & memory_file
        let trace_path = trace_file
            .as_path()
            .canonicalize()
            .unwrap_or(trace_file.clone())
            .to_string_lossy()
            .to_string();
        let memory_path = memory_file
            .as_path()
            .canonicalize()
            .unwrap_or(memory_file.clone())
            .to_string_lossy()
            .to_string();

        let json = cairo_runner
            .get_air_private_input()
            .to_serializable(trace_path, memory_path)
            .serialize_json()
            .map_err(PublicInputError::Serde)?;
        std::fs::write(file_path, json)?;
    }

    if let Some(ref file_name) = args.cairo_pie_output {
        let file_path = Path::new(file_name);
        cairo_runner
            .get_cairo_pie()
            .map_err(CairoRunError::Runner)?
            .write_zip_file(file_path, true)?
    }

    if let Some(ref file_name) = args.cairo_pie_output {
        cairo_runner.get_cairo_pie().unwrap().write_zip_file(file_name, true)?
    }

    Ok(())
}
