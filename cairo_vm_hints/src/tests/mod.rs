use cairo_vm::{
    cairo_run,
    vm::{errors::cairo_run_errors::CairoRunError, runners::cairo_runner::CairoRunner},
};

use crate::CustomHintProcessor;

pub fn run_cairo_program(program_content: &[u8]) -> Result<CairoRunner, CairoRunError> {
    let cairo_run_config = cairo_run::CairoRunConfig {
        layout: cairo_vm::types::layout_name::LayoutName::all_cairo,
        allow_missing_builtins: Some(true),
        ..Default::default()
    };

    Ok(cairo_run::cairo_run(
        program_content,
        &cairo_run_config,
        &mut CustomHintProcessor::new(),
    )?)
}
