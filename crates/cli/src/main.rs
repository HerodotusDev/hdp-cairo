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
use tracing as _;
use tracing_subscriber::EnvFilter;
use types::error::Error;

#[derive(Parser, Debug)]
#[clap(author, version, about)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct UpdateArgs {
    #[arg(short = 'c', long = "clean", help = "Clean build, longer and heavier, but clean")]
    clean: bool,
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
    Update(UpdateArgs),
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let cli = Cli::parse();

    match cli.command {
        Commands::DryRun(_) | Commands::FetchProofs(_) | Commands::SoundRun(_) => {
            check_env()?;
        }
        _ => {}
    }

    match cli.command {
        Commands::DryRun(args) => dry_run::run_with_args(args).await?,
        Commands::FetchProofs(args) => fetcher::run_with_args(args).await?,
        Commands::SoundRun(args) => sound_run::run_with_args(args).await?,
        Commands::ProgramHash { program } => {
            let program_file = std::fs::read(program.unwrap_or(PathBuf::from(HDP_COMPILED_JSON))).map_err(Error::IO)?;
            let program = Program::from_bytes(&program_file, Some(cairo_run::CairoRunConfig::default().entrypoint))?;

            println!(
                "{}",
                compute_program_hash_chain(&program.get_stripped_program().unwrap(), 0)?.to_hex_string()
            );
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

            result?;
        }
        Commands::EnvInfo => print_env_info()?,
        Commands::Update(args) => {
            //? Runs the update/install command: curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
            // Original curl version (commented for debug):
            let mut curl = Command::new("curl")
                .arg("-fsSL")
                .arg("https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh")
                .stdout(Stdio::piped())
                .spawn()
                .map_err(Error::IO)?;

            let mut script = Vec::new();
            curl.stdout.take().unwrap().read_to_end(&mut script)?;

            let mut bash_cmd = Command::new("bash");
            bash_cmd.arg("-s").arg("--").stdin(Stdio::piped());

            if args.clean {
                bash_cmd.arg("--clean");
            }

            let status = bash_cmd
                .spawn()
                .and_then(|mut child| {
                    child.stdin.as_mut().unwrap().write_all(&script)?;
                    child.wait()
                })
                .map_err(Error::IO)?;

            if !status.success() {
                return Err(Box::new(Error::IO(std::io::Error::other("Installer failed"))) as Box<dyn std::error::Error>);
            }
        }
    }

    Ok(())
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
