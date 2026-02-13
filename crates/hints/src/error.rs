use thiserror::Error;

#[derive(Debug, Error)]
pub enum HintExecutionError {
    #[error("hint '{hint_name}' failed: {reason}")]
    HintFailed { hint_name: &'static str, reason: String },

    #[error("variable '{var}' not found in scope '{scope}'")]
    VariableNotFound { var: &'static str, scope: &'static str },

    #[error("index {index} out of bounds for {collection} (length {len})")]
    IndexOutOfBounds {
        collection: &'static str,
        index: usize,
        len: usize,
    },
}
