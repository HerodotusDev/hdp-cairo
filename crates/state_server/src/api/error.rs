use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};
use thiserror::Error;
use tracing::error;

use crate::mpt::error::Error;

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("MPT operation failed: {0}")]
    MptError(#[from] Error),

    #[error("Resource not found")]
    NotFound,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        match &self {
            ApiError::MptError(e) => {
                error!("API Mpt error: {}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()).into_response()
            }
            ApiError::NotFound => (StatusCode::NOT_FOUND, self.to_string()).into_response(),
        }
    }
}
