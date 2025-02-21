#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::path::PathBuf;

use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout::CairoLayoutParams, layout_name::LayoutName, program::Program},
};
use clap::Parser;
use dry_hint_processor::{
    syscall_handler::{evm, starknet},
    CustomHintProcessor,
};
use dry_run::DRY_RUN_COMPILED_JSON;
use hints::vars;
use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
use tracing::debug;
use types::{error::Error, param::Param, CasmContractClass, HDPDryRunInput};

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[arg(short = 'm', long = "compiled_module", help = "Path to the compiled module file")]
    compiled_module: PathBuf,
    #[arg(short = 'i', long = "inputs", help = "Path to the JSON file containing input parameters")]
    inputs: Option<PathBuf>,
    #[arg(
        short = 'o',
        long = "output",
        default_value = "dry_run_output.json",
        help = "Path where the output JSON will be written"
    )]
    output: PathBuf,
    #[arg(
        long = "print_output",
        default_value_t = true,
        help = "Print program output to stdout [default: true]"
    )]
    print_output: bool,
    /// When using dynamic layout, it's parameters must be specified through a layout params file.
    #[clap(long = "layout", default_value = "starknet_with_keccak", value_enum)]
    layout: LayoutName,
    /// Required when using with dynamic layout.
    /// Ignored otherwise.
    #[clap(long = "cairo_layout_params_file", required_if_eq("layout", "dynamic"))]
    cairo_layout_params_file: Option<PathBuf>,
    #[structopt(long = "secure_run")]
    secure_run: Option<bool>,
    #[arg(long = "pie", default_value = None, help = "Path where the Cairo PIE zip file will be written")]
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
        layout: args.layout,
        secure_run: args.secure_run,
        allow_missing_builtins: args.allow_missing_builtins,
        dynamic_layout_params: cairo_layout_params,
        ..Default::default()
    };

    // Load the Program
    let program_file = std::fs::read(DRY_RUN_COMPILED_JSON).map_err(Error::IO)?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
    let params: Vec<Param> = if let Some(input_path) = args.inputs {
        serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };

    let mut hint_processor = CustomHintProcessor::new(HDPDryRunInput { compiled_class, params });

    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor).unwrap();

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

    std::fs::write(
        args.output,
        serde_json::to_vec::<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>(
            &cairo_runner
                .exec_scopes
                .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler>>(vars::scopes::SYSCALL_HANDLER)
                .unwrap()
                .syscall_handler
                .try_read()
                .unwrap(),
        )
        .map_err(|e| Error::IO(e.into()))?,
    )
    .map_err(Error::IO)?;

    Ok(())
}
