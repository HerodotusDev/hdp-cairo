#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{env, path::PathBuf};

use cairo_vm::{
    cairo_run::{cairo_run_program, CairoRunConfig},
    types::{layout_name::LayoutName, program::Program, relocatable::Relocatable},
    vm::runners::cairo_runner::CairoRunner,
};
use clap::Parser;
use dotenvy as _;
use serde_json as _;
use sound_hint_processor::CustomHintProcessor;
use tokio as _;
use tracing::{debug, info, instrument, warn};
use tracing_subscriber as _;
use types::{error::Error, param::Param, CasmContractClass, HDPInput, HDPOutput, InjectedState, ProofsData};

#[cfg(feature = "stwo")]
use crate::prove::prover_input_from_runner;
#[cfg(feature = "stwo")]
pub mod prove;

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
        short = 's',
        long = "injected_state",
        help = "Path to the JSON file containing injected_state parameters"
    )]
    pub injected_state: Option<PathBuf>,
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
    #[arg(long = "proof_mode", conflicts_with = "cairo_pie", help = "Configure runner in proof mode")]
    pub proof_mode: bool,

    #[arg(
        long = "cairo_pie",
        default_value = None,
        conflicts_with_all = ["stwo_proof", "proof_mode"],
        help = "Path where the Cairo PIE zip file will be written"
    )]
    pub cairo_pie: Option<PathBuf>,

    #[arg(
        long = "stwo_prover_input",
        default_value = None,
        requires = "proof_mode",
        conflicts_with = "cairo_pie",
        help = "Path where the STWO prover input file will be written"
    )]
    pub stwo_prover_input: Option<PathBuf>,
}

#[instrument(skip(input, cairo_run_config), fields(program = %program_path.display()))]
pub fn run(program_path: PathBuf, cairo_run_config: CairoRunConfig, input: HDPInput) -> Result<(CairoRunner, HDPOutput), Error> {
    debug!(
        chain_proofs = input.chain_proofs.len(),
        state_proofs = input.state_proofs.len(),
        params_count = input.params.len(),
        unconstrained_entries = input.unconstrained.0.len(),
        "Sound run input loaded"
    );
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

    let output = HDPOutput::from_iter(iter);

    Ok((cairo_runner, output))
}

pub fn get_program_path() -> String {
    std::env::var("HDP_SOUND_RUN_PATH").unwrap_or_else(|_| HDP_COMPILED_JSON.to_string())
}

pub async fn run_with_args(args: Args) -> Result<(), Error> {
    info!("Starting sound run execution...");
    info!("Reading compiled module from: {}", args.compiled_module.display());
    info!("Reading proofs from: {}", args.proofs.display());

    let compiled_class_bytes = std::fs::read(&args.compiled_module).map_err(|e| Error::ReadFile {
        path: args.compiled_module.display().to_string(),
        source: e,
    })?;
    let compiled_class: CasmContractClass = serde_json::from_slice(&compiled_class_bytes)?;
    let params: Vec<Param> = if let Some(input_path) = args.inputs {
        let bytes = std::fs::read(&input_path).map_err(|e| Error::ReadFile {
            path: input_path.display().to_string(),
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
    let proofs_path = args.proofs.display().to_string();
    let proofs_bytes = std::fs::read(&args.proofs).map_err(|e| Error::ReadFile {
        path: proofs_path,
        source: e,
    })?;
    let proofs_data: ProofsData = serde_json::from_slice(&proofs_bytes)?;

    let cairo_run_config = CairoRunConfig {
        layout: LayoutName::all_cairo_stwo,
        secure_run: Some(true),
        allow_missing_builtins: Some(false),
        relocate_mem: true,
        trace_enabled: true,
        proof_mode: args.proof_mode,
        ..Default::default()
    };

    let (cairo_runner, output) = run(
        args.program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON)),
        cairo_run_config,
        HDPInput {
            chain_proofs: proofs_data.chain_proofs,
            compiled_class,
            params,
            state_proofs: proofs_data.state_proofs,
            injected_state,
            unconstrained: proofs_data.unconstrained,
        },
    )?;

    if args.print_output {
        println!("{:#?}", output);
    }

    if let Some(ref relocated_trace) = cairo_runner.relocated_trace {
        let step_count = relocated_trace.len();
        info!("Step count ({}): {}", if args.proof_mode { "stwo" } else { "pie" }, step_count);
        if step_count > 10_000_000 {
            warn!(step_count, "Large step count detected");
        }
    }

    if let Some(ref file_name) = args.cairo_pie {
        let pie = cairo_runner.get_cairo_pie().map_err(|e| Error::CairoPie(e.to_string()))?;
        pie.write_zip_file(file_name, true)?;
    }

    if let Some(ref file_name) = args.stwo_prover_input {
        #[cfg(feature = "stwo")]
        {
            let stwo_prover_input = prover_input_from_runner(&cairo_runner)?;
            std::fs::write(file_name, serde_json::to_string(&stwo_prover_input)?).map_err(|e| Error::WriteFile {
                path: file_name.display().to_string(),
                source: e,
            })?;
            info!("Prover Input saved to: {:?}", file_name);
        }
        #[cfg(not(feature = "stwo"))]
        {
            let _ = file_name;
            return Err(Error::Internal(
                "STWO prover input generation is disabled. Rebuild with `--features stwo`.".into(),
            ));
        }
    }

    info!("Sound run completed successfully.");

    Ok(())
}
