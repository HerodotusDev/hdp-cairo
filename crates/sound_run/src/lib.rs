#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{env, path::PathBuf};

use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout_name::LayoutName, program::Program, relocatable::Relocatable},
    vm::runners::cairo_pie::CairoPie,
};
use clap::Parser;
use serde_json as _;
use sound_hint_processor::CustomHintProcessor;
use tokio as _;
use tracing::debug;
use tracing_subscriber as _;
use types::{error::Error, HDPInput, HDPOutput};

pub const HDP_COMPILED_JSON: &str = env!("HDP_COMPILED_JSON");
pub const HDP_PROGRAM_HASH: &str = env!("HDP_PROGRAM_HASH");

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    #[arg(short = 'm', long = "compiled_module", help = "Path to the compiled module file")]
    pub compiled_module: PathBuf,
    #[arg(short = 'i', long = "inputs", help = "Path to the JSON file containing input parameters")]
    pub inputs: Option<PathBuf>,
    #[arg(
        short = 'p',
        long = "proofs",
        default_value = "proofs.json",
        help = "Path to the program proofs file (fetch-proof output)"
    )]
    pub proofs: PathBuf,
    #[arg(
        long = "print_output",
        default_value_t = false,
        help = "Print program output to stdout [default: false]"
    )]
    pub print_output: bool,
    #[arg(long = "cairo_pie_output", default_value = None, help = "Path where the Cairo PIE zip file will be written")]
    pub cairo_pie_output: Option<PathBuf>,
}

pub fn run(input: HDPInput) -> Result<(CairoPie, HDPOutput), Error> {
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: LayoutName::starknet_with_keccak,
        secure_run: Some(true),
        allow_missing_builtins: Some(false),
        ..Default::default()
    };

    let program_file = std::fs::read(get_program_path()).map_err(Error::IO)?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(input);
    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;
    debug!("{:?}", cairo_runner.get_execution_resources());

    let pie = cairo_runner.get_cairo_pie().map_err(|e| Error::CairoPie(e.to_string()))?;

    let segment_index = cairo_runner.vm.get_output_builtin_mut()?.base();
    let segment_size = cairo_runner.vm.segments.compute_effective_sizes()[segment_index];
    let iter = cairo_runner
        .vm
        .get_range(Relocatable::from((segment_index as isize, 0)), segment_size)
        .into_iter()
        .map(|v| v.clone().unwrap().get_int().unwrap());

    let output = HDPOutput::from_iter(iter);

    Ok((pie, output))
}

pub fn get_program_path() -> String {
    std::env::var("HDP_SOUND_RUN_PATH").unwrap_or_else(|_| HDP_COMPILED_JSON.to_string())
}
