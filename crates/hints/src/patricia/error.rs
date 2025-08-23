use cairo_vm::{types::errors::math_errors::MathError, vm::errors::hint_errors::HintError};
use types::Felt252;

use crate::patricia::types::DecodeNodeCase;

#[derive(thiserror::Error, Debug)]
pub enum PatriciaHintError {
    #[error("Assertion failed: case was expected to be 'right', but was {0:?}")]
    AssertCaseRightFailed(DecodeNodeCase),

    #[error("No preimage found for node {0}")]
    PreimageNotFound(Felt252),

    #[error("Preimage value for node {0} has length {1}, expected 3 for a NodeEdge")]
    InvalidEdgePreimageLength(Felt252, usize),

    #[error("Expected a branch node, but found a leaf")]
    UnexpectedLeaf,

    #[error("Expected a node for traversal, but found None")]
    ExpectedNode,

    #[error("Invalid tree structure: Tuple node cannot have two empty children.")]
    InvalidTupleNode,

    #[error(transparent)]
    Math(#[from] MathError),
}
impl From<PatriciaHintError> for HintError {
    fn from(e: PatriciaHintError) -> Self {
        HintError::CustomHint(e.to_string().into_boxed_str())
    }
}
