pub mod read;
pub mod root;
pub mod write;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum KeyError {
    #[error("Conversion Error: {0}")]
    ConversionError(String),
}
