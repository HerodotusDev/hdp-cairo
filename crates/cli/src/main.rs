#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::fs;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use clap::{Parser, Subcommand};
use dry_hint_processor::syscall_handler::{evm, starknet};
use fetcher::{parse_syscall_handler, Fetcher};
use sound_run::HDP_PROGRAM_HASH;
use syscall_handler::SyscallHandler;
use types::{error::Error, param::Param, ChainProofs, HDPDryRunInput, HDPInput};

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
    ProgramHash,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Set default RPC URL for Herodotus Indexer
    std::env::set_var("RPC_URL_HERODOTUS_INDEXER", "https://staging.rs-indexer.api.herodotus.cloud/");

    // Check required environment variables
    for env_var in ["RPC_URL_ETHEREUM", "RPC_URL_STARKNET"] {
        if std::env::var(env_var).is_err() {
            return Err(format!("Missing required environment variable: {}", env_var).into());
        }
    }

    let cli = Cli::parse();

    match cli.command {
        Commands::DryRun(args) => {
            println!("Starting dry run execution...");
            println!("Reading compiled module from: {}", args.compiled_module.display());

            let compiled_class: CasmContractClass = serde_json::from_slice(&std::fs::read(args.compiled_module).map_err(Error::IO)?)?;
            let params: Vec<Param> = if let Some(input_path) = args.inputs {
                serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
            } else {
                Vec::new()
            };

            println!("Executing program...");
            let (syscall_handler, output) = dry_run::run(HDPDryRunInput { compiled_class, params })?;

            if args.print_output {
                println!("{:#?}", output);
            }

            std::fs::write(
                args.output,
                serde_json::to_vec::<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>(&syscall_handler)
                    .map_err(|e| Error::IO(e.into()))?,
            )
            .map_err(Error::IO)?;

            println!("Dry run completed successfully.");
            Ok(())
        }
        Commands::FetchProofs(args) => {
            println!("Reading input file from: {}", args.inputs.display());
            let input_file = fs::read(&args.inputs)?;

            let syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler> =
                serde_json::from_slice(&input_file)?;
            let proof_keys = parse_syscall_handler(syscall_handler)?;

            let fetcher = Fetcher::new(&proof_keys);
            let (evm_proofs, starknet_proofs) = tokio::try_join!(fetcher.collect_evm_proofs(), fetcher.collect_starknet_proofs())?;
            let chain_proofs = vec![
                ChainProofs::EthereumSepolia(evm_proofs),
                ChainProofs::StarknetSepolia(starknet_proofs),
            ];

            println!("Writing proofs to: {}", args.output.display());
            fs::write(
                args.output,
                serde_json::to_string_pretty(&chain_proofs)
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
            let (pie, output) = sound_run::run(HDPInput {
                chain_proofs,
                compiled_class,
                params,
            })?;

            if args.print_output {
                println!("{:#?}", output);
            }

            if let Some(ref file_name) = args.cairo_pie_output {
                pie.write_zip_file(file_name)?
            }

            println!("Sound run completed successfully.");
            Ok(())
        }
        Commands::ProgramHash => {
            println!("{}", HDP_PROGRAM_HASH);
            Ok(())
        }
    }
}
