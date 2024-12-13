#![allow(unused)]

use super::utils::SyscallExecutionError;
pub mod account;
pub mod header;
pub mod receipt;
pub mod storage;
pub mod transaction;

pub trait KeyFetch {
    type Value;
    type Proof;
    fn fetch_value(&self) -> Result<Self::Value, SyscallExecutionError>;
    fn fetch_proof(&self) -> Result<Self::Proof, SyscallExecutionError>;
}
