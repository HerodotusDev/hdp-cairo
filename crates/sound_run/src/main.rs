#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{env, path::PathBuf};

use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout::CairoLayoutParams, layout_name::LayoutName, program::Program},
};
use clap::Parser;
use sound_hint_processor::CustomHintProcessor;
use tracing::debug;
use types::{error::Error, ChainProofs, HDPDryRunInput, HDPInput};

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[structopt(long = "program_input")]
    program_input: PathBuf,
    #[structopt(long = "program_proofs")]
    program_proofs: PathBuf,
    #[clap(long = "trace_file", value_parser)]
    trace_file: Option<PathBuf>,
    #[structopt(long = "print_output")]
    print_output: bool,
    #[structopt(long = "memory_file")]
    memory_file: Option<PathBuf>,
    /// When using dynamic layout, it's parameters must be specified through a layout params file.
    #[clap(long = "layout", default_value = "plain", value_enum)]
    layout: LayoutName,
    /// Required when using with dynamic layout.
    /// Ignored otherwise.
    #[clap(long = "cairo_layout_params_file", required_if_eq("layout", "dynamic"))]
    cairo_layout_params_file: Option<PathBuf>,
    #[structopt(long = "proof_mode")]
    proof_mode: bool,
    #[structopt(long = "secure_run")]
    secure_run: Option<bool>,
    #[clap(long = "air_public_input", requires = "proof_mode")]
    air_public_input: Option<PathBuf>,
    #[clap(
        long = "air_private_input",
        requires_all = ["proof_mode", "trace_file", "memory_file"]
    )]
    air_private_input: Option<PathBuf>,
    #[clap(
        long = "cairo_pie_output",
        // We need to add these air_private_input & air_public_input or else
        // passing cairo_pie_output + either of these without proof_mode will not fail
        conflicts_with_all = ["proof_mode", "air_private_input", "air_public_input"]
    )]
    cairo_pie_output: Option<PathBuf>,
    #[structopt(long = "allow_missing_builtins")]
    allow_missing_builtins: Option<bool>,
}

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt::init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    let cairo_layout_params = match args.cairo_layout_params_file {
        Some(file) => Some(CairoLayoutParams::from_file(&file)?),
        None => None,
    };

    // Init CairoRunConfig
    let cairo_run_config = cairo_run::CairoRunConfig {
        trace_enabled: args.trace_file.is_some() || args.air_public_input.is_some(),
        relocate_mem: args.memory_file.is_some() || args.air_public_input.is_some(),
        layout: args.layout,
        proof_mode: args.proof_mode,
        secure_run: args.secure_run,
        allow_missing_builtins: args.allow_missing_builtins,
        dynamic_layout_params: cairo_layout_params,
        ..Default::default()
    };

    // Locate the compiled program file in the `OUT_DIR` folder.
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set"));
    let program_file_path = out_dir.join("cairo").join("compiled.json");

    let program_file = std::fs::read(program_file_path.as_path()).map_err(Error::IO)?;
    let program_inputs: HDPDryRunInput = serde_json::from_slice(&std::fs::read(args.program_input).map_err(Error::IO)?)?;
    let program_proofs: Vec<ChainProofs> = serde_json::from_slice(&std::fs::read(args.program_proofs).map_err(Error::IO)?)?;

    // Load the Program
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(HDPInput {
        chain_proofs: program_proofs,
        compiled_class: program_inputs.compiled_class,
        params: program_inputs.params,
    });
    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;

    debug!("{:?}", cairo_runner.get_execution_resources());

    if args.print_output {
        let mut output_buffer = "Program Output:\n".to_string();
        cairo_runner.vm.write_output(&mut output_buffer)?;
        print!("{output_buffer}");
    }

    if let Some(ref file_name) = args.cairo_pie_output {
        cairo_runner
            .get_cairo_pie()
            .map_err(|e| Error::CairoPie(e.to_string()))?
            .write_zip_file(file_name)?
    }

    Ok(())
}
