#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{
    io::{Read, Write},
    path::PathBuf,
    process::{Command, Stdio},
};

use cairo_lang_starknet_classes as _;
use cairo_vm::{
    cairo_run::{self},
    program_hash::compute_program_hash_chain,
};
use clap::{Parser, Subcommand};
use dry_hint_processor as _;
use dry_run::Program;
use indexer_client as _;
use serde_json as _;
use sound_run::HDP_COMPILED_JSON;
use syscall_handler as _;
use tracing::{self as _, debug, info, level_filters::LevelFilter};
use tracing_subscriber::EnvFilter;
use types::error::Error;

#[derive(Parser, Debug)]
#[clap(author, version, about)]
struct Cli {
    /// Set the logging level (trace, debug, info, warn, error)
    /// Defaults to INFO if not specified. Can also be set via RUST_LOG environment variable.
    #[arg(long = "log-level", value_name = "LEVEL")]
    log_level: Option<String>,

    /// Set log level to DEBUG (shortcut for --log-level debug)
    #[arg(long = "debug")]
    debug: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct UpdateArgs {
    #[arg(short = 'c', long = "clean", help = "Clean build, longer and heavier, but clean")]
    clean: bool,
    #[arg(
        short = 'l',
        long = "local",
        help = "Build from existing local repository without pulling from GitHub"
    )]
    local: bool,
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct EnvCheckArgs {
    #[arg(
        short = 'i',
        long = "inputs",
        default_value = "dry_run_output.json",
        help = "Path to the dry-run output JSON (the file produced by `hdp dry-run`)"
    )]
    pub inputs: PathBuf,
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
    /// Check which RPC env vars are required for a given dry-run output (and which are missing)
    #[command(name = "env-check")]
    EnvCheck(EnvCheckArgs),
    /// Update HDP CLI
    ///
    /// Runs the update/install command: ```curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash```
    #[command(name = "update")]
    Update(UpdateArgs),
    /// Print the path to the HDP repository directory
    #[command(name = "pwd")]
    Pwd,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    // Parse CLI early to get log level, but don't process commands yet
    let cli = Cli::parse();

    setup_tracing(cli.log_level.as_ref(), cli.debug)?;
    debug!(?cli, "Parsed CLI arguments");

    match &cli.command {
        Commands::DryRun(_) | Commands::FetchProofs(_) | Commands::SoundRun(_) => check_env(&cli.command)?,
        _ => {}
    }

    let command_name = format!("{:?}", cli.command);
    info!(command = %command_name, "Command start");

    let result: Result<(), Box<dyn std::error::Error>> = match cli.command {
        Commands::DryRun(args) => dry_run::run_with_args(args).await.map_err(Into::into),
        Commands::FetchProofs(args) => fetcher::run_with_args(args).await.map_err(Into::into),
        Commands::SoundRun(args) => sound_run::run_with_args(args).await.map_err(Into::into),
        Commands::ProgramHash { program } => {
            let program_path = program.unwrap_or_else(|| PathBuf::from(HDP_COMPILED_JSON));
            let program_file = std::fs::read(&program_path).map_err(Error::IO)?;
            let program = Program::from_bytes(&program_file, Some(cairo_run::CairoRunConfig::default().entrypoint))?;

            let stripped = program.get_stripped_program().map_err(|e| {
                Error::IO(std::io::Error::other(format!(
                    "Failed to strip program at {}: {e}",
                    program_path.display()
                )))
            })?;

            println!("{}", compute_program_hash_chain(&stripped, 0)?.to_hex_string());
            Ok(())
        }
        Commands::Link => {
            let result: Result<(), Error> = (|| {
                println!("🔗 Linking HDP CLI into your project...");

                // Get the current working directory
                let current_dir = std::env::current_dir().map_err(Error::IO)?;

                // Resolve the HDP installation path
                let hdp_path = get_hdp_path()?;

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

            result?;
            Ok(())
        }
        Commands::EnvInfo => print_env_info(),
        Commands::EnvCheck(args) => env_check(args),
        Commands::Update(args) => {
            let script = if args.local {
                // Load script from local filesystem
                let hdp_path = get_hdp_path()?;
                let script_path = hdp_path.join("install-cli.sh");
                std::fs::read(&script_path).map_err(|e| {
                    Error::IO(std::io::Error::new(
                        std::io::ErrorKind::NotFound,
                        format!("Failed to read install script at {}: {}", script_path.display(), e),
                    ))
                })?
            } else {
                // Download script from internet
                let mut curl = Command::new("curl")
                    .arg("-fsSL")
                    .arg("https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh")
                    .stdout(Stdio::piped())
                    .spawn()
                    .map_err(Error::IO)?;

                let mut script = Vec::new();
                curl.stdout
                    .take()
                    .ok_or_else(|| Error::IO(std::io::Error::other("Failed to capture curl stdout")))?
                    .read_to_end(&mut script)?;
                script
            };

            let mut bash_cmd = Command::new("bash");
            bash_cmd.arg("-s").arg("--").stdin(Stdio::piped());

            if args.clean {
                bash_cmd.arg("--clean");
            }
            if args.local {
                bash_cmd.arg("--local");
            }

            let status = bash_cmd
                .spawn()
                .and_then(|mut child| {
                    child
                        .stdin
                        .as_mut()
                        .ok_or_else(|| std::io::Error::other("Failed to open stdin pipe to installer"))?
                        .write_all(&script)?;
                    child.wait()
                })
                .map_err(Error::IO)?;

            if !status.success() {
                return Err(Box::new(Error::IO(std::io::Error::other("Installer failed"))) as Box<dyn std::error::Error>);
            }
            Ok(())
        }
        Commands::Pwd => {
            let hdp_path = get_hdp_path()?;
            println!("{}", hdp_path.display());
            Ok(())
        }
    };

    result?;
    info!(command = %command_name, "Command completed");

    Ok(())
}

fn get_hdp_path() -> Result<PathBuf, Error> {
    std::env::var("HOME")
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
        .map_err(Error::IO)
}

fn print_env_info() -> Result<(), Box<dyn std::error::Error>> {
    println!();
    println!("⚠ To use HDP CLI, you need a .env file in your project directory.");
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

fn env_check(args: EnvCheckArgs) -> Result<(), Box<dyn std::error::Error>> {
    use types::{RPC_URL_HERODOTUS_INDEXER, RPC_URL_OPTIMISM_TESTNET};

    // Touch the constants so `cargo clippy --all-targets` doesn't complain if some are only
    // referenced through the helper. (Keeps the import list stable.)
    let _ = RPC_URL_OPTIMISM_TESTNET;

    let is_missing = |name: &str| -> bool { std::env::var(name).map(|v| v.trim().is_empty()).unwrap_or(true) };

    let mut required = required_env_vars_for_fetch_inputs(&args.inputs)?;
    required.insert(RPC_URL_HERODOTUS_INDEXER);

    let mut missing: Vec<&'static str> = required.iter().copied().filter(|v| is_missing(v)).collect();
    missing.sort();
    missing.dedup();

    println!("Required env vars for `{}`:", args.inputs.display());
    for v in &required {
        println!("- {v}");
    }

    if missing.is_empty() {
        println!();
        println!("✅ All required env vars are set.");
        return Ok(());
    }

    println!();
    println!("❌ Missing env vars:");
    for v in &missing {
        println!("- {v}");
    }
    println!();
    println!("Tip: run `hdp env-info` to print an example `.env` template.");

    Err(format!("Missing required env vars: {}", missing.join(", ")).into())
}

fn check_env(cmd: &Commands) -> Result<(), Box<dyn std::error::Error>> {
    info!("ℹ️  If you're having problems with the .env file, or RPC endpoints, run `hdp env-info` to get more information.");

    let is_missing = |name: &str| -> bool { std::env::var(name).map(|v| v.trim().is_empty()).unwrap_or(true) };

    match cmd {
        // Dry-run may hit RPCs depending on the module, but we can't cheaply infer which ones here.
        // So we don't hard-fail on missing RPC env vars for dry-run; errors will be surfaced with context at call sites.
        Commands::DryRun(_) => Ok(()),

        // Sound-run consumes already-fetched proofs; it should not require network env vars.
        Commands::SoundRun(_) => Ok(()),

        Commands::FetchProofs(args) => {
            use types::RPC_URL_HERODOTUS_INDEXER;

            // Always required for MMR/header proofs.
            if is_missing(RPC_URL_HERODOTUS_INDEXER) {
                let _ = print_env_info();
                return Err(format!("Missing required environment variable: {RPC_URL_HERODOTUS_INDEXER}").into());
            }

            let required = required_env_vars_for_fetch_inputs(&args.inputs)?;
            let mut missing: Vec<&'static str> = required.iter().copied().filter(|v| is_missing(v)).collect();
            missing.sort();
            missing.dedup();

            if !missing.is_empty() {
                let _ = print_env_info();
                return Err(format!("Missing required environment variables for fetch-proofs: {}", missing.join(", ")).into());
            }

            Ok(())
        }

        _ => Ok(()),
    }
}

fn required_env_vars_for_fetch_inputs(inputs_path: &PathBuf) -> Result<std::collections::BTreeSet<&'static str>, Error> {
    use dry_hint_processor::DryRunSyscallHandler;
    use types::{
        ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID,
        RPC_URL_ETHEREUM_MAINNET, RPC_URL_ETHEREUM_TESTNET, RPC_URL_OPTIMISM_MAINNET, RPC_URL_OPTIMISM_TESTNET, RPC_URL_STARKNET_MAINNET,
        RPC_URL_STARKNET_TESTNET, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
    };

    let bytes = std::fs::read(inputs_path).map_err(Error::IO)?;
    let syscall_handler: DryRunSyscallHandler = serde_json::from_slice(&bytes).map_err(Error::SerdeJson)?;

    let proof_keys = fetcher::parse_syscall_handler(syscall_handler).map_err(|e| Error::Internal(e.to_string()))?;

    let mut chain_ids = std::collections::BTreeSet::<types::ChainId>::new();
    for k in proof_keys.evm.header_keys.iter() {
        chain_ids.insert(k.chain_id);
    }
    for k in proof_keys.evm.account_keys.iter() {
        chain_ids.insert(k.chain_id);
    }
    for k in proof_keys.evm.storage_keys.iter() {
        chain_ids.insert(k.chain_id);
    }
    for k in proof_keys.evm.receipt_keys.iter() {
        chain_ids.insert(k.chain_id);
    }
    for k in proof_keys.evm.transaction_keys.iter() {
        chain_ids.insert(k.chain_id);
    }
    for k in proof_keys.starknet.header_keys.iter() {
        chain_ids.insert(k.chain_id);
    }
    for k in proof_keys.starknet.storage_keys.iter() {
        chain_ids.insert(k.chain_id);
    }

    let mut required = std::collections::BTreeSet::<&'static str>::new();
    for chain_id in chain_ids {
        let env_var = match chain_id {
            ETHEREUM_MAINNET_CHAIN_ID => RPC_URL_ETHEREUM_MAINNET,
            ETHEREUM_TESTNET_CHAIN_ID => RPC_URL_ETHEREUM_TESTNET,
            OPTIMISM_MAINNET_CHAIN_ID => RPC_URL_OPTIMISM_MAINNET,
            OPTIMISM_TESTNET_CHAIN_ID => RPC_URL_OPTIMISM_TESTNET,
            STARKNET_MAINNET_CHAIN_ID => RPC_URL_STARKNET_MAINNET,
            STARKNET_TESTNET_CHAIN_ID => RPC_URL_STARKNET_TESTNET,
            _ => continue,
        };
        required.insert(env_var);
    }

    Ok(required)
}

fn setup_tracing(log_level: Option<&String>, debug: bool) -> Result<(), Box<dyn std::error::Error>> {
    // Set up tracing with log level from CLI or default to INFO
    // --log-level takes precedence over --debug
    let level_filter = if let Some(level) = log_level {
        // If log level is specified via CLI, use it
        level
            .parse::<LevelFilter>()
            .map_err(|_| Error::IO(std::io::Error::other("Invalid log level. Use: trace, debug, info, warn, or error")))?
    } else if debug {
        // If --debug flag is set, use DEBUG level
        LevelFilter::DEBUG
    } else {
        // Default to INFO
        LevelFilter::INFO
    };

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::builder().with_default_directive(level_filter.into()).from_env_lossy())
        .init();

    Ok(())
}
