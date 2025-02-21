#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::path::PathBuf;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout_name::LayoutName, program::Program},
};
use clap::{Parser, Subcommand};
use dry_hint_processor::{
    syscall_handler::{evm, starknet},
    CustomHintProcessor,
};
use dry_run::DRY_RUN_COMPILED_JSON;
use fetcher::{parse_syscall_handler, Fetcher};
use hints::vars;
use sound_hint_processor::CustomHintProcessor as CustomHintProcessorSound;
use sound_run::{HDP_COMPILED_JSON, HDP_PROGRAM_HASH};
use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
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
    DryRun {
        #[arg(short = 'm', long = "compiled_module", help = "Path to the compiled module file")]
        compiled_module: PathBuf,
        #[arg(short = 'i', long = "inputs", help = "Path to the JSON file containing input parameters")]
        inputs: Option<PathBuf>,
        #[arg(
            short = 'o',
            long = "output",
            default_value = "dry_run_output.json",
            help = "Path where the output JSON will be written"
        )]
        output: PathBuf,
        #[arg(
            long = "print_output",
            default_value_t = true,
            help = "Print program output to stdout [default: true]"
        )]
        print_output: bool,
    },
    /// Run the sound-run functionality
    SoundRun {
        #[arg(short = 'm', long = "compiled_module", help = "Path to the compiled module file")]
        compiled_module: PathBuf,
        #[arg(short = 'i', long = "inputs", help = "Path to the JSON file containing input parameters")]
        inputs: Option<PathBuf>,
        #[arg(
            short = 'p',
            long = "proofs",
            default_value = "proofs.json",
            help = "Path to the program proofs file (fetch-proof output)"
        )]
        proofs: PathBuf,
        #[arg(
            long = "print_output",
            default_value_t = true,
            help = "Print program output to stdout [default: true]"
        )]
        print_output: bool,
        #[arg(long = "pie", default_value = None, help = "Path where the Cairo PIE zip file will be written")]
        cairo_pie_output: Option<PathBuf>,
    },
    FetchProofs {
        #[arg(
            short = 'i',
            long = "inputs",
            default_value = "dry_run_output.json",
            help = "The output of the dry_run step"
        )]
        inputs: PathBuf,
        #[arg(
            short = 'o',
            long = "output",
            default_value = "proofs.json",
            help = "Path where the output JSON will be written"
        )]
        output: PathBuf,
    },
    ProgramHash {},
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    match cli.command {
        Commands::DryRun {
            compiled_module,
            inputs,
            output,
            print_output,
        } => {
            println!("Starting dry run execution...");
            println!("Reading compiled module from: {}", compiled_module.display());

            let cairo_run_config = cairo_run::CairoRunConfig {
                trace_enabled: false,
                relocate_mem: false,
                layout: LayoutName::starknet_with_keccak,
                secure_run: Some(true),
                ..Default::default()
            };

            let module: CasmContractClass = serde_json::from_slice(&std::fs::read(compiled_module).map_err(Error::IO)?)?;
            let input: Vec<Param> = if let Some(input_path) = inputs {
                serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
            } else {
                Vec::new()
            };

            let dry_run_input = HDPDryRunInput {
                compiled_class: module,
                params: input,
            };

            let program_file = std::fs::read(DRY_RUN_COMPILED_JSON).map_err(Error::IO)?;
            let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

            println!("Executing program...");
            let mut hint_processor = CustomHintProcessor::new(dry_run_input);
            let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor).unwrap();

            if print_output {
                let mut output_buffer = "Program output:\n".to_string();
                cairo_runner.vm.write_output(&mut output_buffer)?;
                print!("{output_buffer}");
            }

            println!("Writing execution results to: {}", output.display());
            std::fs::write(
                output,
                serde_json::to_vec::<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>(
                    &cairo_runner
                        .exec_scopes
                        .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler>>(
                            vars::scopes::SYSCALL_HANDLER,
                        )
                        .unwrap()
                        .syscall_handler
                        .try_read()
                        .unwrap(),
                )
                .map_err(|e| Error::IO(e.into()))?,
            )
            .map_err(Error::IO)?;

            println!("Dry run completed successfully.");
            Ok(())
        }
        Commands::SoundRun {
            compiled_module,
            inputs,
            proofs,
            print_output,
            cairo_pie_output,
        } => {
            println!("Starting sound run execution...");
            println!("Reading compiled module from: {}", compiled_module.display());
            println!("Reading proofs from: {}", proofs.display());

            let module: CasmContractClass = serde_json::from_slice(&std::fs::read(compiled_module).map_err(Error::IO)?)?;
            let input: Vec<Param> = if let Some(input_path) = inputs {
                serde_json::from_slice(&std::fs::read(input_path).map_err(Error::IO)?)?
            } else {
                Vec::new()
            };
            let chain_proofs: Vec<ChainProofs> = serde_json::from_slice(&std::fs::read(proofs).map_err(Error::IO)?)?;

            let program_inputs = HDPInput {
                compiled_class: module,
                params: input,
                chain_proofs,
            };

            let cairo_run_config = cairo_run::CairoRunConfig {
                trace_enabled: false,
                relocate_mem: false,
                layout: LayoutName::starknet_with_keccak,
                secure_run: Some(true),
                ..Default::default()
            };

            // Load the Program
            let program_file = std::fs::read(HDP_COMPILED_JSON).map_err(Error::IO)?;
            let program = Program::from_bytes(&program_file, Some("main"))?;

            println!("Executing program...");
            let mut hint_processor = CustomHintProcessorSound::new(program_inputs);
            let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;

            if print_output {
                let mut output_buffer = "Program output:\n".to_string();
                cairo_runner.vm.write_output(&mut output_buffer)?;
                print!("{output_buffer}");
            }

            if let Some(ref file_name) = cairo_pie_output {
                println!("Writing Cairo PIE to: {}", file_name.display());
                cairo_runner
                    .get_cairo_pie()
                    .map_err(|e| Error::CairoPie(e.to_string()))?
                    .write_zip_file(file_name)?
            }

            println!("Sound run completed successfully.");
            Ok(())
        }
        Commands::FetchProofs { inputs, output } => {
            println!("Reading input file from: {}", inputs.display());
            let input_file = std::fs::read(&inputs).map_err(Error::IO)?;

            let syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler> =
                serde_json::from_slice(&input_file)?;
            let proof_keys = parse_syscall_handler(syscall_handler)?;

            println!("Fetching proofs from Ethereum and Starknet...");
            let fetcher = Fetcher::new(&proof_keys);
            let (evm_proofs, starknet_proofs) = tokio::try_join!(fetcher.collect_evm_proofs(), fetcher.collect_starknet_proofs())?;

            println!("Successfully fetched proofs:");
            println!("  - Ethereum: {} proofs", evm_proofs.len());
            println!("  - Starknet: {} proofs", starknet_proofs.len());

            let chain_proofs = vec![
                ChainProofs::EthereumSepolia(evm_proofs),
                ChainProofs::StarknetSepolia(starknet_proofs),
            ];

            println!("Writing proofs to: {}", output.display());
            std::fs::write(
                &output,
                serde_json::to_string_pretty(&chain_proofs)
                    .map_err(|e| Error::IO(e.into()))?
                    .as_bytes(),
            )
            .map_err(Error::IO)?;

            println!("Proofs have been saved successfully.");
            Ok(())
        }
        Commands::ProgramHash {} => {
            println!("{}", HDP_PROGRAM_HASH);
            Ok(())
        }
    }
}
