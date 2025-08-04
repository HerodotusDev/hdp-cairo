#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{fs, path::PathBuf};

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{cairo_run, program_hash::compute_program_hash_chain};
use clap::{Parser, Subcommand};
use dry_hint_processor::syscall_handler::{evm, injected_state, starknet};
use dry_run::{Program, DRY_RUN_COMPILED_JSON};
use fetcher::run_fetcher;
use serde::{Deserialize, Serialize};
use sound_run::HDP_COMPILED_JSON;
use syscall_handler::SyscallHandler;
use types::{actions::action::Action, error::Error, param::Param, ChainProofs, HDPDryRunInput, HDPInput};

#[derive(Deserialize)]
struct FetcherInput {
    #[serde(flatten)]
    syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>,
}

#[derive(Serialize, Debug)]
struct FetcherOutput {
    chain_proofs: Vec<ChainProofs>,
    #[serde(skip_serializing_if = "Option::is_none")]
    upsert_results: Option<serde_json::Value>,
}

#[derive(Serialize, Debug)]
struct UpsertActionsRequest {
    actions: Vec<Action>,
}

#[derive(Parser, Debug)]
#[clap(author, version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Run the dry-run functionality
    #[command(name = "dry-run")]
    DryRun(dry_run::Args),
    /// Run the proofs fetcher functionality
    #[command(name = "fetch-proofs")]
    FetchProofs(fetcher::Args),
    /// Run the sound-run functionality
    #[command(name = "sound-run")]
    SoundRun(sound_run::Args),
    /// Get program hash
    #[command(name = "program-hash")]
    ProgramHash {
        #[arg(short = 'p', long = "program", help = "Path to the compiled program")]
        program: Option<PathBuf>,
    },
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    let cli = Cli::parse();

    match cli.command {
        Commands::DryRun(args) => {
            check_env()?;

            println!("Starting dry run execution...");
            println!("Reading compiled module from: {}", args.compiled_module.display());

            let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
            let params: Vec<Param> = if let Some(input_path) = args.inputs {
                serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
            } else {
                Vec::new()
            };

            println!("Executing program...");
            let (syscall_handler, output) = dry_run::run(
                args.program.unwrap_or(PathBuf::from(DRY_RUN_COMPILED_JSON)),
                HDPDryRunInput { compiled_class, params },
            )?;

            if args.print_output {
                println!("{:#?}", output);
            }

            std::fs::write(
                args.output,
                serde_json::to_vec::<
                    SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>,
                >(&syscall_handler)
                .map_err(|e| Error::IO(e.into()))?,
            )
            .map_err(Error::IO)?;

            println!("Dry run completed successfully.");
            Ok(())
        }
        Commands::FetchProofs(args) => {
            check_env()?;

            println!("Reading input file from: {}", args.inputs.display());
            let input_file = fs::read(&args.inputs)?;

            let fetcher_input: FetcherInput = serde_json::from_slice(&input_file)?;

            let chain_proofs = run_fetcher(fetcher_input.syscall_handler.clone()).await?;

            // Extract actions from injected_state_call_contract_handler
            let actions = &fetcher_input
                .syscall_handler
                .call_contract_handler
                .injected_state_call_contract_handler
                .actions;

            // Process actions if present
            let upsert_results = if !actions.is_empty() {
                println!("Processing {} actions...", actions.len());

                let state_server_url = std::env::var("INJECTED_STATE_BASE_URL").unwrap_or_else(|_| "http://localhost:3000".to_string());

                let client = reqwest::Client::new();
                let upsert_request = UpsertActionsRequest { actions: actions.clone() };

                match client
                    .post(&format!("{}/upsert-actions", state_server_url))
                    .json(&upsert_request)
                    .send()
                    .await
                {
                    Ok(response) => {
                        if response.status().is_success() {
                            match response.json::<serde_json::Value>().await {
                                Ok(result) => {
                                    println!("Upsert actions processed successfully.");
                                    Some(result)
                                }
                                Err(e) => {
                                    eprintln!("Failed to parse upsert response: {}", e);
                                    None
                                }
                            }
                        } else {
                            eprintln!("Upsert actions failed with status: {}", response.status());
                            None
                        }
                    }
                    Err(e) => {
                        eprintln!("Failed to send upsert request: {}", e);
                        None
                    }
                }
            } else {
                None
            };

            let output = FetcherOutput {
                chain_proofs,
                upsert_results,
            };

            println!("Writing proofs to: {}", args.output.display());
            fs::write(
                args.output,
                serde_json::to_string_pretty(&output)
                    .map_err(|e| fetcher::FetcherError::IO(e.into()))?
                    .as_bytes(),
            )?;

            println!("Proofs have been saved successfully.");
            Ok(())
        }
        Commands::SoundRun(args) => {
            println!("Starting sound run execution...");
            println!("Reading compiled module from: {}", args.compiled_module.display());
            println!("Reading proofs from: {}", args.proofs.display());

            let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
            let params: Vec<Param> = if let Some(input_path) = args.inputs {
                serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
            } else {
                Vec::new()
            };
            let chain_proofs: Vec<ChainProofs> = serde_json::from_slice(&std::fs::read(args.proofs).map_err(Error::IO)?)?;

            println!("Executing program...");
            let (pie, output) = sound_run::run(
                args.program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON)),
                HDPInput {
                    chain_proofs,
                    compiled_class,
                    params,
                },
            )?;

            if args.print_output {
                println!("{:#?}", output);
            }

            if let Some(ref file_name) = args.cairo_pie_output {
                pie.write_zip_file(file_name, true)?
            }

            println!("Sound run completed successfully.");
            Ok(())
        }
        Commands::ProgramHash { program } => {
            let program_file = std::fs::read(program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON))).map_err(Error::IO)?;
            let program = Program::from_bytes(&program_file, Some(cairo_run::CairoRunConfig::default().entrypoint))?;

            println!(
                "{}",
                compute_program_hash_chain(&program.get_stripped_program().unwrap(), 0)?.to_hex_string()
            );
            Ok(())
        }
    }
}

fn check_env() -> Result<(), Box<dyn std::error::Error>> {
    // Check required environment variables
    for env_var in ["RPC_URL_HERODOTUS_INDEXER"] {
        if std::env::var(env_var).is_err() {
            return Err(format!("Missing required environment variable: {}", env_var).into());
        }
    }

    Ok(())
}
