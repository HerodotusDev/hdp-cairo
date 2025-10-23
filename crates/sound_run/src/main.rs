#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::path::{Path, PathBuf};

use cairo_vm::{self as _, cairo_run::CairoRunConfig, types::layout_name::LayoutName};
use clap::Parser;
use sound_hint_processor as _;
use sound_run::{Args, HDP_COMPILED_JSON};
use stwo_cairo_adapter::adapter::adapter_shards;
use tracing::{self as _, info};
use tracing_subscriber::EnvFilter;
use types::{error::Error, param::Param, CasmContractClass, HDPInput, InjectedState, ProofsData};

#[tokio::main(flavor = "multi_thread", worker_threads = 1)]
async fn main() -> Result<(), Error> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let args = Args::try_parse_from(std::env::args()).map_err(Error::Cli)?;

    let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
    let params: Vec<Param> = if let Some(input_path) = args.inputs {
        serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
    } else {
        Vec::new()
    };
    let injected_state: InjectedState = if let Some(path) = args.injected_state {
        serde_json::from_slice(&std::fs::read(path).map_err(Error::IO)?)?
    } else {
        InjectedState::default()
    };
    let proofs_data: ProofsData = serde_json::from_slice(&std::fs::read(args.proofs).map_err(Error::IO)?)?;

    let cairo_run_config = CairoRunConfig {
        layout: LayoutName::all_cairo_stwo,
        secure_run: Some(true),
        allow_missing_builtins: Some(false),
        relocate_mem: true,
        trace_enabled: true,
        proof_mode: args.proof_mode,
        ..Default::default()
    };

    let (cairo_runner, output) = sound_run::run(
        args.program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON)),
        cairo_run_config,
        HDPInput {
            chain_proofs: proofs_data.chain_proofs,
            compiled_class,
            params,
            state_proofs: proofs_data.state_proofs,
            injected_state,
        },
    )?;

    if args.print_output {
        println!("{:#?}", output);
    }

    if let Some(ref file_name) = args.cairo_pie {
        let pie = cairo_runner.get_cairo_pie().map_err(|e| Error::CairoPie(e.to_string()))?;
        pie.write_zip_file(file_name, true)?;
    }

    if let Some(ref file_name_str) = args.stwo_prover_input {
        let file_path = Path::new(file_name_str);

        let stem = file_path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();

        let extension = file_path
            .extension()
            .map(|s| format!(".{}", s.to_string_lossy()))
            .unwrap_or_default();

        let stwo_prover_inputs = adapter_shards(&cairo_runner, 4000000);

        for (idx, input) in stwo_prover_inputs.into_iter().enumerate() {
            let new_file_name = format!("{}-{}{}", stem, idx, extension);
            std::fs::write(&new_file_name, serde_json::to_string(&input)?)?;
            info!("Prover Input saved to: {}", new_file_name);
        }
    }

    Ok(())
}
