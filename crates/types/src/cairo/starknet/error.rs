use thiserror::Error;

#[derive(Debug, Error)]
pub enum CairoStarknetError {
    #[error("invalid field count for {what}: expected {expected}, got {got}")]
    InvalidFieldCount { what: &'static str, expected: usize, got: usize },

    #[error("field index out of bounds for {what}: index={index}, len={len}")]
    FieldIndexOutOfBounds { what: &'static str, index: usize, len: usize },

    #[error("invalid starknet version string: {version}")]
    InvalidVersionString { version: String },
}
