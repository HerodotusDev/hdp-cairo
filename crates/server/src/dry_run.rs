use std::{env, path::PathBuf};

use axum::Json;
use cairo_vm::{
    cairo_run::{self, cairo_run_program},
    types::{layout::CairoLayoutParams, layout_name::LayoutName, program::Program},
};
use dry_hint_processor::{
    CustomHintProcessor,
    syscall_handler::{evm, starknet},
};
use hints::vars;
use serde::Deserialize;
use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
use types::{HDPDryRunInput, error::Error};

use crate::error::AppError;

#[derive(Debug, Deserialize)]
pub struct DryRunRequest {
    params: Option<CairoLayoutParams>,
    layout: LayoutName,
    input: HDPDryRunInput,
}

#[utoipa::path(
    get,
    path = "/dry_run",
    request_body = ref("DryRunRequest") // TODO implement ToSchema (big and tedious task impl when explicitly needed)
)]
pub async fn root(
    Json(value): Json<DryRunRequest>,
) -> Result<Json<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>, AppError> {
    // Init CairoRunConfig
    let cairo_run_config = cairo_run::CairoRunConfig {
        trace_enabled: false,
        relocate_mem: false,
        layout: value.layout,
        proof_mode: false,
        secure_run: Some(true),
        allow_missing_builtins: Some(true),
        dynamic_layout_params: value.params,
        ..Default::default()
    };

    // Locate the compiled program file in the `OUT_DIR` folder.
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set"));
    let program_file_path = out_dir.join("cairo").join("dry_run_compiled.json");

    let program_file = std::fs::read(program_file_path).map_err(Error::IO)?;

    // Load the Program
    let program = Program::from_bytes(&program_file, Some(cairo_run_config.entrypoint))?;

    let mut hint_processor = CustomHintProcessor::new(value.input);
    let cairo_runner = cairo_run_program(&program, &cairo_run_config, &mut hint_processor).unwrap();

    Ok(Json(
        cairo_runner
            .exec_scopes
            .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler>>(vars::scopes::SYSCALL_HANDLER)?
            .syscall_handler
            .try_read()?
            .clone(),
    ))
}
