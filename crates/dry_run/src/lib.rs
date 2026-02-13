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
    syscall_handler::{evm, injected_state, starknet, unconstrained},
    CustomHintProcessor, DryRunSyscallHandler,
};
use hints::vars;
use serde_json as _;
use syscall_handler::SyscallHandlerWrapper;
use tokio as _;
use tracing::{debug, info, instrument};
use tracing_subscriber as _;
use types::{error::Error, param::Param, CasmContractClass, HDPDryRunInput, HDPDryRunOutput, InjectedState};

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
        short = 's',
        long = "injected_state",
        help = "Path to the JSON file containing injected_state parameters"
    )]
    pub injected_state: Option<PathBuf>,
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

#[allow(clippy::type_complexity)]
#[instrument(skip(input), fields(program = %program_path.display()))]
pub fn run(program_path: PathBuf, input: HDPDryRunInput) -> Result<(DryRunSyscallHandler, HDPDryRunOutput), Error> {
    info!("Starting dry run execution");
    debug!(params_count = input.params.len(), "Input parameters loaded");
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: LayoutName::all_cairo,
        secure_run: Some(true),
        allow_missing_builtins: Some(false),
        ..Default::default()
    };

    info!("Program path: {}", program_path.display());
    let program_file = std::fs::read(&program_path).map_err(|e| Error::ReadFile {
        path: program_path.display().to_string(),
        source: e,
    })?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(input);
    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor).map_err(Box::new)?;
    let resources = cairo_runner
        .get_execution_resources()
        .map_err(|err| Error::Internal(format!("Failed to read execution resources: {err}")))?;
    debug!(?resources, "Execution resources");
    info!(n_steps = resources.n_steps, "Execution completed");

    let syscall_handler = cairo_runner
        .exec_scopes
        .get::<SyscallHandlerWrapper<
            evm::CallContractHandler,
            starknet::CallContractHandler,
            injected_state::CallContractHandler,
            unconstrained::CallContractHandler,
        >>(vars::scopes::SYSCALL_HANDLER)
        .map_err(|e| Error::Internal(format!("Missing syscall handler in exec scopes: {e}")))?
        .syscall_handler
        .try_read()
        .map_err(|e| Error::Internal(format!("Failed to read syscall handler lock: {e}")))?
        .clone();

    let segment_index = cairo_runner.vm.get_output_builtin_mut()?.base();
    let segment_size = cairo_runner.vm.segments.compute_effective_sizes()[segment_index];
    let iter = cairo_runner
        .vm
        .get_range(Relocatable::from((segment_index as isize, 0)), segment_size)
        .into_iter()
        .map(|v| {
            let v = v.clone().ok_or_else(|| Error::ReturnValueExtraction {
                segment: segment_index,
                reason: "missing output value".to_string(),
            })?;
            v.get_int()
                .ok_or_else(|| Error::ReturnValueExtraction {
                    segment: segment_index,
                    reason: "output value is not an integer".to_string(),
                })
                .map(|x| x.to_owned())
        })
        .collect::<Result<Vec<_>, Error>>()?
        .into_iter();

    let output = HDPDryRunOutput::from_iter(iter);

    Ok((syscall_handler, output))
}

pub async fn run_with_args(args: Args) -> Result<(), Error> {
    info!("Starting dry run execution...");
    info!("Reading compiled module from: {}", args.compiled_module.display());
    let compiled_class_bytes = std::fs::read(&args.compiled_module).map_err(|e| Error::ReadFile {
        path: args.compiled_module.display().to_string(),
        source: e,
    })?;
    let compiled_class: CasmContractClass = serde_json::from_slice(&compiled_class_bytes)?;
    let params: Vec<Param> = if let Some(path) = args.inputs {
        let bytes = std::fs::read(&path).map_err(|e| Error::ReadFile {
            path: path.display().to_string(),
            source: e,
        })?;
        serde_json::from_slice(&bytes)?
    } else {
        Vec::new()
    };
    let injected_state: InjectedState = if let Some(path) = args.injected_state {
        let bytes = std::fs::read(&path).map_err(|e| Error::ReadFile {
            path: path.display().to_string(),
            source: e,
        })?;
        serde_json::from_slice(&bytes)?
    } else {
        InjectedState::default()
    };

    info!("Executing program...");
    let (syscall_handler, output) = run(
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

    let out_path = args.output.display().to_string();
    std::fs::write(
        &args.output,
        serde_json::to_vec::<DryRunSyscallHandler>(&syscall_handler).map_err(|e| Error::IO(e.into()))?,
    )
    .map_err(|e| Error::WriteFile { path: out_path, source: e })?;

    info!("Dry run completed successfully.");

    Ok(())
}
