pub mod header;
pub mod storage;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum KeyError {
    #[error("Conversion Error: {0}")]
    ConversionError(String),
}
