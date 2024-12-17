#![allow(unused)]

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
