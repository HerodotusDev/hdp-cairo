use cairo_vm::cairo_run::{self, cairo_run_program};
pub use cairo_vm::types::{layout_name::LayoutName, program::Program};
use dry_hint_processor::{
    syscall_handler::{evm, starknet},
    CustomHintProcessor,
};
use hints::vars;
use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
use types::{error::Error, HDPDryRunInput};

pub const DRY_RUN_COMPILED_JSON: &str = env!("DRY_RUN_COMPILED_JSON");

pub fn exec(input: HDPDryRunInput) -> Result<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>, Error> {
    // Relaxed settings for dry run
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: LayoutName::starknet_with_keccak,
        ..Default::default()
    };

    let program_file = std::fs::read(DRY_RUN_COMPILED_JSON).map_err(Error::IO)?;
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(input);
    let cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor)?;

    let syscall_handler = cairo_runner
        .exec_scopes
        .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler>>(vars::scopes::SYSCALL_HANDLER)
        .unwrap()
        .syscall_handler
        .try_read()
        .unwrap()
        .clone();

    Ok(syscall_handler)
}
