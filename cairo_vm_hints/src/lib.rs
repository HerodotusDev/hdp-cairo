#![forbid(unsafe_code)]
#![allow(async_fn_in_trait)]
pub mod cairo_types;
pub mod hint_processor;
pub mod hints;
pub mod provider;
pub mod syscall_handler;

use cairo_vm::vm::errors::cairo_run_errors::CairoRunError;
pub use hint_processor::CustomHintProcessor;

#[derive(thiserror::Error, Debug)]
pub enum HdpOsError {
    #[error("Error: {0}")]
    CatchAll(String),
    #[error("PIE Parse Error: {0}")]
    PieParsing(String),
    #[error("PIE Zip Error: {0}")]
    PieZipping(String),
    #[error("PIE Encode Error: {0}")]
    PieEncoding(String),
    #[error(transparent)]
    Args(#[from] clap::error::Error),
    #[error("Runner Error: {0}")]
    Runner(CairoRunError),
    #[error("Output Error: {0}")]
    Output(String),
    #[error(transparent)]
    IO(#[from] std::io::Error),
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
}

#[cfg(test)]
pub mod tests;
