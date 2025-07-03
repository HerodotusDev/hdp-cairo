#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::path::PathBuf;

pub use cairo_vm::types::{layout_name::LayoutName, program::Program};
use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::relocatable::Relocatable,
};
use clap::Parser;
use dotenvy as _;
use dry_hint_processor::{
    syscall_handler::{evm, injected_state, starknet},
    CustomHintProcessor,
};
use hints::vars;
use serde_json as _;
use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
use tokio as _;
use tracing::debug;
use tracing_subscriber as _;
use types::{error::Error, HDPDryRunInput, HDPDryRunOutput};

pub const DRY_RUN_COMPILED_JSON: &str = env!("DRY_RUN_COMPILED_JSON");

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    #[arg(short = 'p', long = "program", help = "Path to the compiled dry run hdp program")]
    pub program: Option<PathBuf>,
    #[arg(short = 'm', long = "compiled_module", help = "Path to the compiled module file")]
    pub compiled_module: PathBuf,
    #[arg(short = 'i', long = "inputs", help = "Path to the JSON file containing input parameters")]
    pub inputs: Option<PathBuf>,
    #[arg(
        short = 'o',
        long = "output",
        default_value = "dry_run_output.json",
        help = "Path where the output JSON will be written"
    )]
    pub output: PathBuf,
    #[arg(
        long = "print_output",
        default_value_t = false,
        help = "Print program output to stdout [default: false]"
    )]
    pub print_output: bool,
    #[structopt(long = "allow_missing_builtins")]
    pub allow_missing_builtins: Option<bool>,
}

pub fn run(
    program_path: PathBuf,
    input: HDPDryRunInput,
) -> Result<
    (
        SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>,
        HDPDryRunOutput,
    ),
    Error,
> {
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: LayoutName::all_cairo,
        secure_run: Some(true),
        allow_missing_builtins: Some(false),
        ..Default::default()
    };

    println!("Program path: {}", program_path.display());
    let program_file = std::fs::read(program_path).map_err(Error::IO)?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(input);
    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;
    debug!("{:?}", cairo_runner.get_execution_resources());

    let syscall_handler = cairo_runner
        .exec_scopes
        .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>>(
            vars::scopes::SYSCALL_HANDLER,
        )
        .unwrap()
        .syscall_handler
        .try_read()
        .unwrap()
        .clone();

    let segment_index = cairo_runner.vm.get_output_builtin_mut()?.base();
    let segment_size = cairo_runner.vm.segments.compute_effective_sizes()[segment_index];
    let iter = cairo_runner
        .vm
        .get_range(Relocatable::from((segment_index as isize, 0)), segment_size)
        .into_iter()
        .map(|v| v.clone().unwrap().get_int().unwrap());

    let output = HDPDryRunOutput::from_iter(iter);

    Ok((syscall_handler, output))
}
