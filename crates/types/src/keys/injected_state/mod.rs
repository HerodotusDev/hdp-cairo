pub mod id_to_root;
pub mod read;
pub mod root_to_id;
pub mod write;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum KeyError {
    #[error("Conversion Error: {0}")]
    ConversionError(String),
}
