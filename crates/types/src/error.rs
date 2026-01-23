use cairo_vm::{
    air_public_input::PublicInputError,
    cairo_run::EncodeTraceError,
    types::errors::program_errors::ProgramError,
    vm::errors::{cairo_run_errors::CairoRunError, memory_errors::MemoryError, trace_errors::TraceError, vm_errors::VirtualMachineError},
    Felt252,
};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error("invalid arguments")]
    Cli(#[from] clap::Error),
    #[error("failed to interact with the file system")]
    IO(#[from] std::io::Error),
    #[error("failed to read file '{path}': {source}")]
    ReadFile {
        path: String,
        #[source]
        source: std::io::Error,
    },
    #[error("failed to write file '{path}': {source}")]
    WriteFile {
        path: String,
        #[source]
        source: std::io::Error,
    },
    #[error("missing required environment variable '{var}' (hint: run `hdp env-info` for setup)")]
    MissingEnv {
        var: &'static str,
        #[source]
        source: std::env::VarError,
    },
    #[error(transparent)]
    EncodeTrace(#[from] EncodeTraceError),
    #[error(transparent)]
    VirtualMachine(#[from] VirtualMachineError),
    #[error(transparent)]
    Trace(#[from] TraceError),
    #[error(transparent)]
    PublicInput(#[from] PublicInputError),
    #[error(transparent)]
    CairoRunError(#[from] Box<CairoRunError>),
    #[error("Failed to compile to cairo_pie:\n {0}")]
    CairoPie(String),
    #[error(transparent)]
    Program(#[from] ProgramError),
    #[error(transparent)]
    Memory(#[from] MemoryError),
    #[error("Cairo program panicked with {panic_values:?}")]
    RunPanic { panic_values: Vec<Felt252> },
    #[error("Function signature has no return types")]
    NoRetTypesInSignature,
    #[error("failed to extract return values from VM segment {segment}: {reason}")]
    ReturnValueExtraction { segment: usize, reason: String },
    #[error("Internal error: {0}")]
    Internal(String),
    #[error("Function expects arguments of size {expected} and received {actual} instead.")]
    ArgumentsSizeMismatch { expected: i16, actual: i16 },
    #[error("Function param {param_index} only partially contains argument {arg_index}.")]
    ArgumentUnaligned { param_index: usize, arg_index: usize },
    #[error("Only programs returning `Array<Felt252>` can be currently proven. Try serializing the final values before returning them")]
    IllegalReturnValue,
    #[error("Only programs with `Array<Felt252>` as an input can be currently proven. Try inputting the serialized version of the input and deserializing it on main")]
    IllegalInputValue,
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
}
