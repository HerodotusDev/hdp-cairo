#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{
    fs,
    io::{Read, Write},
    path::PathBuf,
    process::{Command, Stdio},
};

use cairo_air::utils::{serialize_proof_to_file, ProofFormat};
use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    cairo_run::{self, CairoRunConfig},
    program_hash::compute_program_hash_chain,
};
use clap::{Parser, Subcommand};
use dry_hint_processor::syscall_handler::{evm, injected_state, starknet};
use dry_run::{LayoutName, Program, DRY_RUN_COMPILED_JSON};
use fetcher::{parse_syscall_handler, Fetcher};
use sound_run::{
    prove::{prove, prover_input_from_runner, secure_pcs_config},
    HDP_COMPILED_JSON,
};
use stwo_cairo_prover::stwo_prover::core::vcs::blake2_merkle::Blake2sMerkleChannel;
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
    /// Print example .env file with info
    #[command(name = "env-info")]
    EnvInfo,
    /// Update HDP CLI
    ///
    /// Runs the update/install command: ```curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash```
    #[command(name = "update")]
    Update,
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

            if let Some(ref relocated_trace) = cairo_runner.relocated_trace {
                println!(
                    "Step count ({}): {:?}",
                    if args.proof_mode { "stwo" } else { "pie" },
                    relocated_trace.len()
                );
            }

            if let Some(ref file_name) = args.cairo_pie {
                let pie = cairo_runner.get_cairo_pie().map_err(|e| Error::CairoPie(e.to_string()))?;
                pie.write_zip_file(file_name, true)?;
            }

            if let Some(ref file_name) = args.stwo_proof {
                let stwo_prover_input = prover_input_from_runner(&cairo_runner);
                std::fs::write(file_name, serde_json::to_string(&stwo_prover_input)?)?;

                let cairo_proof = prove(stwo_prover_input, secure_pcs_config());
                serialize_proof_to_file::<Blake2sMerkleChannel>(&cairo_proof, file_name.into(), ProofFormat::Json)
                    .expect("Failed to serialize proof");

                println!("Proof saved to: {:?}", file_name);
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
        Commands::EnvInfo => print_env_info(),
        Commands::Update => {
            //? Runs the update/install command: curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
            let mut curl = Command::new("curl")
                .arg("-fsSL")
                .arg("https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh")
                .stdout(Stdio::piped())
                .spawn()
                .map_err(Error::IO)?;

            let mut script = Vec::new();
            curl.stdout.take().unwrap().read_to_end(&mut script)?;
            let status = Command::new("bash")
                .stdin(Stdio::piped())
                .spawn()
                .and_then(|mut child| {
                    child.stdin.as_mut().unwrap().write_all(&script)?;
                    child.wait()
                })
                .map_err(Error::IO)?;

            if !status.success() {
                return Err(Box::new(Error::IO(std::io::Error::other("Installer failed"))) as Box<dyn std::error::Error>);
            }

            Ok(())
        }
    }
}

fn print_env_info() -> Result<(), Box<dyn std::error::Error>> {
    println!();
    println!("⚠ To use hdp-cli, you need a .env file in your project directory.");
    println!("ℹ Here's an example .env file:");
    println!("────────────────────────────────────────");

    // Read and display the example.env file
    let home_dir = std::env::var("HOME").map_err(|_| "Could not find HOME environment variable")?;
    let example_env_path = PathBuf::from(home_dir).join(".local/share/hdp/example.env");
    let example_env_content = std::fs::read_to_string(&example_env_path).map_err(Error::IO)?;
    println!("{}", example_env_content);
    println!();

    println!("────────────────────────────────────────");
    println!("➤ Copy this to your project directory as .env and configure the values as needed.");
    println!();
    println!("ℹ Note that the ethereum RPC URLs need to be archive nodes.");
    println!("ℹ Note that the starknet RPC URLs need to be pathfinder full nodes.");
    println!();

    Ok(())
}

fn check_env() -> Result<(), Box<dyn std::error::Error>> {
    println!("ℹ️  If you're having problems with the .env file, or RPC endpoints, run `hdp-cli env-info` to get more information.");

    // Check required environment variables
    for env_var in ["RPC_URL_HERODOTUS_INDEXER"] {
        if std::env::var(env_var).is_err() {
            let _ = print_env_info(); // Ignore the error to avoid accidentally hiding the error below
            return Err(format!("Missing required environment variable: {}", env_var).into());
        }
    }

    Ok(())
}
