use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};
use thiserror::Error;
use tracing::error;

use crate::mpt::error::Error as MptError;

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("Database connection failed: {0}")]
    DatabaseConnection(#[from] anyhow::Error),

    #[error("MPT operation failed: {0}")]
    MptError(#[from] MptError),

    #[error("Resource not found")]
    NotFound,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        match &self {
            ApiError::NotFound => (StatusCode::NOT_FOUND, self.to_string()).into_response(),
            _ => {
                error!("API error: {}", self);
                (StatusCode::INTERNAL_SERVER_ERROR, self.to_string()).into_response()
            }
        }
    }
}
