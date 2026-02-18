#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::{
    collections::HashMap,
    io::{Read, Write},
    path::{Path, PathBuf},
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
use tracing::{self as _, info, level_filters::LevelFilter};
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
pub struct UploadArgs {
    /// API key for authentication
    #[arg(short = 'k', long = "api-key")]
    api_key: Option<String>,
    /// HDP server URL (defaults to HDP_SERVER_URL env var or http://localhost:3001)
    #[arg(short = 'u', long = "url")]
    server_url: Option<String>,
    /// Module description
    #[arg(long = "description")]
    description: Option<String>,
    /// Tags (comma-separated)
    #[arg(long = "tags")]
    tags: Option<String>,
    /// License
    #[arg(long = "license")]
    license: Option<String>,
    /// Version changelog
    #[arg(long = "changelog")]
    changelog: Option<String>,
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
    /// Print the path to the HDP repository directory
    #[command(name = "pwd")]
    Pwd,
    /// Upload a module to the HDP server
    ///
    /// Builds the module, collects source files, and uploads everything to the HDP server.
    /// Must be run from the module root directory (where Scarb.toml is located).
    #[command(name = "upload")]
    Upload(UploadArgs),
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    // Parse CLI early to get log level, but don't process commands yet
    let cli = Cli::parse();

    setup_tracing(cli.log_level.as_ref(), cli.debug)?;

    match cli.command {
        Commands::DryRun(_) | Commands::FetchProofs(_) | Commands::SoundRun(_) => check_env()?,
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
        }
        Commands::EnvInfo => print_env_info()?,
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
                curl.stdout.take().unwrap().read_to_end(&mut script)?;
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
                    child.stdin.as_mut().unwrap().write_all(&script)?;
                    child.wait()
                })
                .map_err(Error::IO)?;

            if !status.success() {
                return Err(Box::new(Error::IO(std::io::Error::other("Installer failed"))) as Box<dyn std::error::Error>);
            }
        }
        Commands::Pwd => {
            let hdp_path = get_hdp_path()?;
            println!("{}", hdp_path.display());
        }
        Commands::Upload(upload_args) => {
            upload_module(upload_args).await?;
        }
    }

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

fn check_env() -> Result<(), Box<dyn std::error::Error>> {
    info!("ℹ️  If you're having problems with the .env file, or RPC endpoints, run `hdp env-info` to get more information.");

    // Check required environment variables
    for env_var in ["RPC_URL_HERODOTUS_INDEXER"] {
        if std::env::var(env_var).is_err() {
            let _ = print_env_info(); // Ignore the error to avoid accidentally hiding the error below
            return Err(format!("Missing required environment variable: {}", env_var).into());
        }
    }

    Ok(())
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

async fn upload_module(args: UploadArgs) -> Result<(), Box<dyn std::error::Error>> {
    use walkdir::WalkDir;

    let UploadArgs {
        api_key,
        server_url,
        description,
        tags,
        license,
        changelog,
    } = args;

    info!("📦 Starting module upload...");

    // Get current directory
    let current_dir = std::env::current_dir().map_err(Error::IO)?;
    let scarb_toml_path = current_dir.join("Scarb.toml");

    if !scarb_toml_path.exists() {
        return Err("Scarb.toml not found in current directory. Please run this command from the module root directory.".into());
    }

    // Read Scarb.toml
    let scarb_toml_content = std::fs::read_to_string(&scarb_toml_path).map_err(Error::IO)?;
    let scarb_toml: toml::Value = toml::from_str(&scarb_toml_content)?;

    let package = scarb_toml
        .get("package")
        .ok_or("Missing [package] section in Scarb.toml")?;

    let module_name = package
        .get("name")
        .and_then(|v| v.as_str())
        .ok_or("Missing 'name' field in [package] section")?
        .to_string();

    let module_version = package
        .get("version")
        .and_then(|v| v.as_str())
        .ok_or("Missing 'version' field in [package] section")?
        .to_string();

    info!("📋 Module: {} v{}", module_name, module_version);

    // Build the module with scarb
    info!("🔨 Building module with scarb...");
    let build_output = Command::new("scarb")
        .arg("build")
        .current_dir(&current_dir)
        .output()
        .map_err(|e| Error::IO(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("Failed to run scarb build: {}. Make sure scarb is installed and in PATH.", e),
        )))?;

    if !build_output.status.success() {
        let stderr = String::from_utf8_lossy(&build_output.stderr);
        return Err(format!("Scarb build failed:\n{}", stderr).into());
    }

    info!("✅ Build successful");

    let compiled_file_path = find_compiled_contract_class_file(&current_dir, &module_name)?
        .ok_or_else(|| {
            format!(
                "Compiled contract class file not found for module '{}'. \
                 Make sure the module has a [[target.starknet-contract]] section in Scarb.toml \
                 and that 'scarb build' produced a *.compiled_contract_class.json artifact.",
                module_name
            )
        })?;
    info!("📄 Found compiled program: {}", compiled_file_path.display());

    // Read compiled program
    let compiled_program_bytes = std::fs::read(&compiled_file_path).map_err(Error::IO)?;
    let compiled_program_json: serde_json::Value = serde_json::from_slice(&compiled_program_bytes)?;

    // Extract compiler version from compiled program
    let compiler_version = compiled_program_json
        .get("compiler_version")
        .and_then(|v| v.as_str())
        .ok_or("Missing compiler_version in compiled program")?
        .to_string();

    // Try to find ABI file (usually in target/dev/<package_name>_<target_name>.contract_class.json)
    let abi_file_path = compiled_file_path
        .to_string_lossy()
        .replace(".compiled_contract_class.json", ".contract_class.json");
    let abi_file_path = PathBuf::from(abi_file_path);
    
    let abi_json: Option<serde_json::Value> = if abi_file_path.exists() {
        let abi_content = std::fs::read_to_string(&abi_file_path).map_err(Error::IO)?;
        let contract_class: serde_json::Value = serde_json::from_str(&abi_content)?;
        contract_class.get("abi").cloned()
    } else {
        None
    };

    // Collect all source files from src directory
    let src_dir = current_dir.join("src");
    if !src_dir.exists() {
        return Err("src directory not found".into());
    }

    let mut source_files: HashMap<String, String> = HashMap::new();
    for entry in WalkDir::new(&src_dir) {
        let entry = entry.map_err(|e| Error::IO(std::io::Error::other(e.to_string())))?;
        let path = entry.path();
        
        if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("cairo") {
            let relative_path = path
                .strip_prefix(&current_dir)
                .map_err(|e| Error::IO(std::io::Error::other(format!("Failed to get relative path: {}", e))))?
                .to_string_lossy()
                .to_string();
            
            let content = std::fs::read_to_string(path).map_err(Error::IO)?;
            source_files.insert(relative_path, content);
        }
    }

    info!("📁 Collected {} source files", source_files.len());

    // Get API key
    let api_key = api_key
        .or_else(|| std::env::var("HERODOTUS_CLOUD_API_KEY").ok())
        .ok_or("API key required. Provide via --api-key flag or HERODOTUS_CLOUD_API_KEY environment variable")?;

    // Get server URL
    let server_url = server_url
        .or_else(|| std::env::var("HDP_SERVER_URL").ok())
        .unwrap_or_else(|| "http://localhost:3001".to_string());

    info!("🚀 Uploading to {}...", server_url);

    // Build multipart form
    let client = reqwest::Client::new();
    let mut form = reqwest::multipart::Form::new();

    // Add compiled module
    form = form.part("module", reqwest::multipart::Part::bytes(compiled_program_bytes)
        .file_name("module.json")
        .mime_str("application/json")?);

    // Add required fields
    form = form.text("name", module_name.clone());
    form = form.text("compiler_version", compiler_version);
    form = form.text("version", module_version.clone());

    // Add optional fields
    if let Some(desc) = description {
        form = form.text("description", desc);
    }
    if let Some(tags_str) = tags {
        form = form.text("tags", tags_str);
    }
    if let Some(lic) = license {
        form = form.text("license", lic);
    }
    if let Some(changelog_str) = changelog {
        form = form.text("version_changelog", changelog_str);
    }

    // Add source files as JSON
    let source_files_json = serde_json::to_string(&source_files)?;
    form = form.text("source_files", source_files_json);

    // Add ABI if available
    if let Some(abi) = abi_json {
        let abi_str = serde_json::to_string(&abi)?;
        form = form.text("abi", abi_str);
    }

    // Add Scarb.toml
    form = form.text("scarb_toml", scarb_toml_content);

    // Upload
    let response = client
        .post(format!("{}/modules/upload", server_url))
        .header("X-API-KEY", api_key)
        .multipart(form)
        .send()
        .await?;

    if !response.status().is_success() {
        let status = response.status();
        let error_text = response.text().await?;
        return Err(format!("Upload failed ({}): {}", status, error_text).into());
    }

    let result: serde_json::Value = response.json().await?;
    info!("✅ Module uploaded successfully!");
    info!("   Module ID: {}", result.get("id").and_then(|v| v.as_str()).unwrap_or("N/A"));
    info!("   Program Hash: {}", result.get("programHash").and_then(|v| v.as_str()).unwrap_or("N/A"));
    
    println!();
    println!("✅ Successfully uploaded module '{}' v{}", module_name, module_version);

    Ok(())
}

fn find_compiled_contract_class_file(current_dir: &Path, module_name: &str) -> Result<Option<PathBuf>, Error> {
    let mut search_dirs = Vec::new();
    let mut cursor = Some(current_dir.to_path_buf());

    // Search current dir and all parents for target/dev artifacts.
    while let Some(dir) = cursor {
        search_dirs.push(dir.join("target/dev"));
        cursor = dir.parent().map(Path::to_path_buf);
    }

    // De-duplicate while preserving order.
    search_dirs.dedup();

    let mut all_candidates = Vec::new();
    for dir in search_dirs {
        if !dir.exists() {
            continue;
        }
        for entry in std::fs::read_dir(&dir).map_err(Error::IO)? {
            let entry = entry.map_err(Error::IO)?;
            let file_name = entry.file_name().to_string_lossy().to_string();
            if file_name.ends_with(".compiled_contract_class.json") {
                all_candidates.push(entry.path());
            }
        }
    }

    if all_candidates.is_empty() {
        return Ok(None);
    }

    // Prefer artifacts that include "<module_name>_" in filename.
    let module_prefix = format!("{}_", module_name);
    let mut preferred: Vec<PathBuf> = all_candidates
        .iter()
        .filter(|path| {
            path.file_name()
                .and_then(|v| v.to_str())
                .map(|n| n.contains(&module_prefix))
                .unwrap_or(false)
        })
        .cloned()
        .collect();

    if preferred.is_empty() {
        preferred = all_candidates;
    }

    preferred.sort_by_key(|path| {
        std::fs::metadata(path)
            .and_then(|m| m.modified())
            .ok()
    });

    Ok(preferred.pop())
}
