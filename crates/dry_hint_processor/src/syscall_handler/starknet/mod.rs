use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use serde::{Deserialize, Serialize};
use std::{collections::HashSet, hash::Hash};
use strum_macros::FromRepr;
use syscall_handler::traits::SyscallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::cairo::new_syscalls::{CallContractRequest, CallContractResponse};
use types::keys;

pub mod header;
pub mod storage;

#[derive(FromRepr)]
pub enum CallHandlerId {
    Storage = 0,
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandler {
    pub key_set: HashSet<DryRunKey>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, _request: Self::Request, _vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        unimplemented!()
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        unreachable!()
    }
}

impl TryFrom<Felt252> for CallHandlerId {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        Self::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })
    }
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Clone)]
#[serde(rename_all = "lowercase")]
pub enum DryRunKey {
    Header(keys::starknet::header::Key),
    Storage(keys::starknet::storage::Key),
}

impl DryRunKey {
    pub fn is_storage(&self) -> bool {
        matches!(self, Self::Storage(_))
    }
}