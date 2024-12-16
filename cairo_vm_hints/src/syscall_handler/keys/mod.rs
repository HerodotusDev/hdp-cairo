#![allow(unused)]

use crate::hint_processor::models::proofs::Proofs;

use super::utils::SyscallExecutionError;
pub mod account;
pub mod header;
pub mod receipt;
pub mod storage;
pub mod transaction;

pub trait FetchValue {
    type Value;
    fn fetch_value(&self) -> Result<Self::Value, SyscallExecutionError>;
}

pub trait FetchProofs {
    type Key;
    fn fetch_proofs(&self, keys: Vec<Self::Key>) -> Result<Proofs, SyscallExecutionError>;
}
