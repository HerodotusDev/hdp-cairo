#![allow(async_fn_in_trait)]
#![forbid(unsafe_code)]
#![warn(unused_crate_dependencies)]
#![warn(unused_extern_crates)]

use std::{
    env,
    io::{self, Write},
    path::PathBuf,
};

use bincode::enc::write::Writer;
use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout_name::LayoutName, program::Program, relocatable::Relocatable},
    vm::runners::cairo_runner::CairoRunner,
};
use clap::Parser;
use dotenvy as _;
use serde_json as _;
use sound_hint_processor::CustomHintProcessor;
use tokio as _;
use tracing::debug;
use tracing_subscriber as _;
use types::{error::Error, HDPInput, HDPOutput};

pub const HDP_COMPILED_JSON: &str = env!("HDP_COMPILED_JSON");

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    #[arg(short = 'p', long = "program", help = "Path to the compiled hdp program")]
    pub program: Option<PathBuf>,
    #[arg(short = 'm', long = "compiled_module", help = "Path to the compiled module file")]
    pub compiled_module: PathBuf,
    #[arg(short = 'i', long = "inputs", help = "Path to the JSON file containing input parameters")]
    pub inputs: Option<PathBuf>,
    #[arg(
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
    #[arg(
        long = "cairo_pie_output",
        // We need to add these air_private_input & air_public_input or else
        // passing cairo_pie_output + either of these without proof_mode will not fail
        conflicts_with_all = ["proof_mode", "air_private_input", "air_public_input"],
        default_value = None,
        help = "Path where the Cairo PIE zip file will be written"
    )]
    pub cairo_pie_output: Option<PathBuf>,

    #[arg(long = "trace_file", value_parser)]
    pub trace_file: Option<PathBuf>,
    #[arg(long = "memory_file")]
    pub memory_file: Option<PathBuf>,
    #[arg(long = "air_public_input", requires = "proof_mode")]
    pub air_public_input: Option<String>,
    #[arg(
        long = "air_private_input",
        requires_all = ["proof_mode", "trace_file", "memory_file"]
    )]
    pub air_private_input: Option<String>,
}

pub fn run(args: &Args, input: HDPInput) -> Result<(CairoRunner, HDPOutput), Error> {
    let program_path = args.program.clone().unwrap_or(PathBuf::from(HDP_COMPILED_JSON));

    let trace_enabled = args.trace_file.is_some() || args.air_public_input.is_some();

    let cairo_run_config = cairo_run::CairoRunConfig {
        allow_missing_builtins: Some(false),
        layout: LayoutName::recursive_with_poseidon,
        proof_mode: true,
        relocate_mem: args.memory_file.is_some() || args.air_public_input.is_some(),
        secure_run: Some(true),
        trace_enabled,
        ..Default::default()
    };

    debug!("Program path: {}", program_path.display());
    let program_file = std::fs::read(program_path).map_err(Error::IO)?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(input);
    let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;
    debug!("{:?}", cairo_runner.get_execution_resources());

    let segment_index = cairo_runner.vm.get_output_builtin_mut()?.base();
    let segment_size = cairo_runner.vm.segments.compute_effective_sizes()[segment_index];
    let iter = cairo_runner
        .vm
        .get_range(Relocatable::from((segment_index as isize, 0)), segment_size)
        .into_iter()
        .map(|v| v.clone().unwrap().get_int().unwrap());

    let output = HDPOutput::from_iter(iter);

    Ok((cairo_runner, output))
}

pub struct FileWriter {
    buf_writer: io::BufWriter<std::fs::File>,
    bytes_written: usize,
}

impl Writer for FileWriter {
    fn write(&mut self, bytes: &[u8]) -> Result<(), bincode::error::EncodeError> {
        self.buf_writer.write_all(bytes).map_err(|e| bincode::error::EncodeError::Io {
            inner: e,
            index: self.bytes_written,
        })?;

        self.bytes_written += bytes.len();

        Ok(())
    }
}

impl FileWriter {
    pub fn new(buf_writer: io::BufWriter<std::fs::File>) -> Self {
        Self {
            buf_writer,
            bytes_written: 0,
        }
    }

    pub fn flush(&mut self) -> io::Result<()> {
        self.buf_writer.flush()
    }
}
