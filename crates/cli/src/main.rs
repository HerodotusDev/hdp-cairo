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
use fetcher::{parse_syscall_handler, Fetcher};
use sound_run::HDP_COMPILED_JSON;
use syscall_handler::SyscallHandler;
use types::{
    error::Error, param::Param, ChainProofs, HDPDryRunInput, HDPInput, InjectedState, ProofsData, ETHEREUM_MAINNET_CHAIN_ID,
    ETHEREUM_TESTNET_CHAIN_ID, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
};

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
    /// Link globally installed HDP CLI into your project
    #[command(name = "link")]
    Link,
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
            let injected_state: InjectedState = if let Some(path) = args.injected_state {
                serde_json::from_slice(&std::fs::read(path).map_err(Error::IO)?)?
            } else {
                InjectedState::default()
            };

            println!("Executing program...");
            let (syscall_handler, output) = dry_run::run(
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

            let syscall_handler: SyscallHandler<
                evm::CallContractHandler,
                starknet::CallContractHandler,
                injected_state::CallContractHandler,
            > = serde_json::from_slice(&input_file)?;
            let proof_keys = parse_syscall_handler(syscall_handler)?;

            let fetcher = Fetcher::new(&proof_keys);
            let (evm_proofs_mainnet, evm_proofs_sepolia, starknet_proofs_mainnet, starknet_proofs_sepolia, state_proofs) = tokio::try_join!(
                fetcher.collect_evm_proofs(ETHEREUM_MAINNET_CHAIN_ID),
                fetcher.collect_evm_proofs(ETHEREUM_TESTNET_CHAIN_ID),
                fetcher.collect_starknet_proofs(STARKNET_MAINNET_CHAIN_ID),
                fetcher.collect_starknet_proofs(STARKNET_TESTNET_CHAIN_ID),
                fetcher.collect_state_proofs(),
            )?;
            let chain_proofs = vec![
                ChainProofs::EthereumMainnet(evm_proofs_mainnet),
                ChainProofs::EthereumSepolia(evm_proofs_sepolia),
                ChainProofs::StarknetMainnet(starknet_proofs_mainnet),
                ChainProofs::StarknetSepolia(starknet_proofs_sepolia),
            ];

            println!("Writing proofs to: {}", args.output.display());

            fs::write(
                args.output,
                serde_json::to_string_pretty(&(chain_proofs, state_proofs))
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
            let injected_state: InjectedState = if let Some(path) = args.injected_state {
                serde_json::from_slice(&std::fs::read(path).map_err(Error::IO)?)?
            } else {
                InjectedState::default()
            };
            let proofs_data: ProofsData = serde_json::from_slice(&std::fs::read(args.proofs).map_err(Error::IO)?)?;

            let (pie, output) = sound_run::run(
                args.program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON)),
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
        Commands::Link => {
            let result: Result<(), Error> = (|| {
                println!("🔗 Linking HDP CLI into your project...");

                // Get the current working directory
                let current_dir = std::env::current_dir().map_err(Error::IO)?;

                // Resolve the HDP installation path
                let hdp_path = std::env::var("HOME")
                    .map_err(|_| std::io::Error::new(std::io::ErrorKind::NotFound, "Failed to get HOME directory"))
                    .and_then(|home| {
                        let path = format!("{}/.local/share/hdp", home);
                        let expanded_path = PathBuf::from(&path);
                        if expanded_path.exists() {
                            Ok(expanded_path)
                        } else {
                            Err(std::io::Error::new(
                                std::io::ErrorKind::NotFound,
                                format!("HDP installation not found at: {}", path),
                            ))
                        }
                    })
                    .map_err(Error::IO)?;

                let target_path = current_dir.join("hdp_cairo");

                // Check if target already exists
                if target_path.exists() {
                    if target_path.is_symlink() {
                        println!("⚠️  Symlink 'hdp_cairo' already exists. Removing it first...");
                        std::fs::remove_file(&target_path).map_err(Error::IO)?;
                    } else {
                        return Err(Error::IO(std::io::Error::new(
                            std::io::ErrorKind::AlreadyExists,
                            "Target 'hdp_cairo' already exists and is not a symlink. Please remove it first.",
                        )));
                    }
                }

                // Create the symlink
                std::os::unix::fs::symlink(&hdp_path, &target_path).map_err(Error::IO)?;

                // Verify the symlink was created successfully
                if !target_path.exists() {
                    return Err(Error::IO(std::io::Error::other(
                        "Failed to create symlink - target does not exist after creation",
                    )));
                }

                println!("✅ Successfully linked HDP CLI into your project!");
                println!();
                println!("📝 Next steps:");
                println!("   1. Add the following to your Scarb.toml dependencies:");
                println!();
                println!("      [dependencies]");
                println!("      hdp_cairo = {{ path = \"hdp_cairo\" }}");
                println!();
                println!("   2. You can now import HDP modules in your Cairo code:");
                println!("      use hdp_cairo::{{ ... }};");
                println!();
                println!("🎉 Happy coding with HDP!");

                Ok(())
            })();

            result.map_err(|e| Box::new(e) as Box<dyn std::error::Error>)
        }
    }
}

fn check_env() -> Result<(), Box<dyn std::error::Error>> {
    println!();
    println!("Note that the ethereum RPC URLs need to be archive nodes.");
    println!("Note that the starknet RPC URLs need to be pathfinder full nodes.");
    println!();

    // Check required environment variables
    for env_var in ["RPC_URL_HERODOTUS_INDEXER"] {
        if std::env::var(env_var).is_err() {
            return Err(format!("Missing required environment variable: {}", env_var).into());
        }
    }

    Ok(())
}
