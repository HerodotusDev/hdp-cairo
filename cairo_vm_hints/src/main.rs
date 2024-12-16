#![forbid(unsafe_code)]
#![allow(async_fn_in_trait)]
pub mod cairo_types;
pub mod hint_processor;
pub mod hints;
pub mod provider;
pub mod syscall_handler;

use cairo_vm::cairo_run::CairoRunConfig;
use cairo_vm::types::layout_name::LayoutName;
use cairo_vm::types::program::Program;
use cairo_vm::vm::errors::vm_exception::VmException;
use cairo_vm::vm::runners::cairo_runner::CairoRunner;
use clap::{Parser, ValueHint};
use hdp_cairo_vm_hints::HdpOsError;
use hint_processor::CustomHintProcessor;
use hints::vars;
use std::{fs, path::PathBuf};
use syscall_handler::evm::dryrun::{SyscallHandler, SyscallHandlerWrapper};

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
    let program_inputs = std::fs::read(args.program_input).map_err(HdpOsError::IO)?;

    // Load the Program
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint)).map_err(|e| HdpOsError::Runner(e.into()))?;

    // Init cairo runner
    let mut cairo_runner = CairoRunner::new(
        &program,
        cairo_run_config.layout,
        None,
        cairo_run_config.proof_mode,
        cairo_run_config.trace_enabled,
    )
    .map_err(|e| HdpOsError::Runner(e.into()))?;

    // Init the Cairo VM
    let end = cairo_runner
        .initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false))
        .map_err(|e| HdpOsError::Runner(e.into()))?;

    // Run the Cairo VM
    let mut hint_processor = CustomHintProcessor::new(serde_json::from_slice(&program_inputs)?);
    cairo_runner
        .run_until_pc(end, &mut hint_processor)
        .map_err(|err| VmException::from_vm_error(&cairo_runner, err))
        .map_err(|e| HdpOsError::Runner(e.into()))?;

    fs::write(
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
