use thiserror::Error;

#[derive(Debug, Error)]
pub enum CairoEvmError {
    #[error("RLP decode failed for {what}: {err}")]
    RlpDecode { what: &'static str, err: String },

    #[error("missing required field {field} for {what}")]
    MissingField { what: &'static str, field: &'static str },

    #[error("unsupported function {function_id} for {what}")]
    UnsupportedFunction { what: &'static str, function_id: String },

    #[error("index out of bounds for {what}: {index_name}={index}, len={len}")]
    IndexOutOfBounds {
        what: &'static str,
        index_name: &'static str,
        index: usize,
        len: usize,
    },

    #[error("internal invariant violated for {what}: {info}")]
    InternalInvariant { what: &'static str, info: &'static str },
}
