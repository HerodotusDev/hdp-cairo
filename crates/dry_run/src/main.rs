#![forbid(unsafe_code)]
#![allow(async_fn_in_trait)]
use cairo_vm::{
    cairo_run::CairoRunConfig,
    types::{layout_name::LayoutName, program::Program},
    vm::{
        errors::vm_exception::VmException,
        runners::cairo_runner::{CairoRunner, RunnerMode},
    },
};
use clap::{Parser, ValueHint};
use dry_hint_processor::{
    syscall_handler::evm::{SyscallHandler, SyscallHandlerWrapper},
    CustomHintProcessor,
};
use hints::vars;
use std::path::PathBuf;
use types::HDPDryRunInput;

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[clap(value_parser, value_hint=ValueHint::FilePath)]
    filename: PathBuf,
    /// When using dynamic layout, it's parameters must be specified through a layout params file.
    #[clap(long = "layout", default_value = "plain", value_enum)]
    layout: LayoutName,
    #[structopt(long = "proof_mode")]
    proof_mode: bool,
    #[structopt(long = "program_input")]
    program_input: PathBuf,
    #[structopt(long = "program_output")]
    program_output: PathBuf,
}

fn main() -> Result<(), HdpOsError> {
    let args = Args::try_parse_from(std::env::args()).map_err(HdpOsError::Args)?;

    // Init CairoRunConfig
    let cairo_run_config = CairoRunConfig {
        layout: args.layout,
        relocate_mem: true,
        trace_enabled: true,
        ..Default::default()
    };

    let program_file = std::fs::read(args.filename).map_err(HdpOsError::IO)?;
    let program_inputs: HDPDryRunInput = serde_json::from_slice(&std::fs::read(args.program_input).map_err(HdpOsError::IO)?)?;

    // Load the Program
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint)).map_err(|e| HdpOsError::Runner(e.into()))?;

    let runner_mode = if cairo_run_config.proof_mode {
        RunnerMode::ProofModeCairo1
    } else {
        RunnerMode::ExecutionMode
    };

    // Init cairo runner
    let mut cairo_runner = CairoRunner::new_v2(&program, cairo_run_config.layout, None, runner_mode, cairo_run_config.trace_enabled)
        .map_err(|e| HdpOsError::Runner(e.into()))?;

    // Init the Cairo VM
    let end = cairo_runner
        .initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false))
        .map_err(|e| HdpOsError::Runner(e.into()))?;

    // Run the Cairo VM
    let mut hint_processor = CustomHintProcessor::new(program_inputs);
    cairo_runner
        .run_until_pc(end, &mut hint_processor)
        .map_err(|err| VmException::from_vm_error(&cairo_runner, err))
        .map_err(|e| HdpOsError::Runner(e.into()))?;

    cairo_runner.vm.compute_segments_effective_sizes();
    println!("{:?}", cairo_runner.get_execution_resources());

    std::fs::write(
        args.program_output,
        serde_json::to_vec::<SyscallHandler>(
            &cairo_runner
                .exec_scopes
                .get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)
                .unwrap()
                .syscall_handler
                .try_read()
                .unwrap(),
        )
        .map_err(|e| HdpOsError::IO(e.into()))?,
    )
    .map_err(HdpOsError::IO)?;

    Ok(())
}

use cairo_vm::vm::errors::cairo_run_errors::CairoRunError;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum HdpOsError {
    #[error(transparent)]
    Args(#[from] clap::error::Error),
    #[error("Runner Error: {0}")]
    Runner(CairoRunError),
    #[error("Output Error: {0}")]
    Output(String),
    #[error(transparent)]
    IO(#[from] std::io::Error),
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
}
