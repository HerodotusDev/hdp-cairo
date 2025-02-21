use clap::{Parser, Subcommand};
use std::path::PathBuf;
use types::{error::Error, param::Param, HDPDryRunInput};
use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
use hints::vars;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout_name::LayoutName, program::Program},
};
use dry_hint_processor::{
    syscall_handler::{evm, starknet},
    CustomHintProcessor,
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
    DryRun {
        #[arg(long = "compiled_module")]
        compiled_module: PathBuf,
        #[arg(long = "inputs")]
        inputs: PathBuf,
        #[arg(long = "output", default_value = "output.json")]
        output: PathBuf,
        #[arg(long = "print_output", default_value_t = true)]
        print_output: bool,
        #[arg(long = "proof_mode", default_value_t = false)]
        proof_mode: bool,
    },
    // Add other commands here as needed
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
            proof_mode,
        } => {
            let cairo_run_config = cairo_run::CairoRunConfig {
                trace_enabled: false,
                relocate_mem: false,
                layout: LayoutName::starknet_with_keccak,
                proof_mode,
                secure_run: None,
                ..Default::default()
            };

            let module: CasmContractClass = serde_json::from_slice(&std::fs::read(compiled_module).map_err(Error::IO)?)?;
            let input: Vec<Param> = serde_json::from_slice(&std::fs::read(inputs).map_err(Error::IO)?)?;

            let dry_run_input = HDPDryRunInput {
                compiled_class: module,
                params: input,
            };

            let program_file = std::fs::read("DRY_RUN_COMPILED_JSON").map_err(Error::IO)?;
            let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

            let mut hint_processor = CustomHintProcessor::new(dry_run_input);
            let mut cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor).unwrap();

            if print_output {
                let mut output_buffer = "Program Output:\n".to_string();
                cairo_runner.vm.write_output(&mut output_buffer)?;
                print!("{output_buffer}");
            }

            std::fs::write(
                output,
                serde_json::to_vec::<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>(
                    &cairo_runner
                        .exec_scopes
                        .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler>>(vars::scopes::SYSCALL_HANDLER)
                        .unwrap()
                        .syscall_handler
                        .try_read()
                        .unwrap(),
                )
                .map_err(|e| Error::IO(e.into()))?,
            )
            .map_err(Error::IO)?;

            Ok(())
        }
    }
}
