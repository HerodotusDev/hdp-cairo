use cairo_vm::vm::errors::cairo_run_errors::CairoRunError;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum HdpOsError {
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
