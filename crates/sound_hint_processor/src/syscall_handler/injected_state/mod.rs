use std::collections::HashMap;

use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::new_syscalls::{CallContractRequest, CallContractResponse},
    proofs::injected_state::Action,
    Felt252,
};

pub mod id_to_root;
pub mod read;
pub mod root_to_id;
pub mod write;

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    Read = 0,
    Write = 1,
    IdToRoot = 2,
    RootToId = 3,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CallContractHandler {
    pub key_set: HashMap<Felt252, Vec<Action>>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, _vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let call_handler_id = CallHandlerId::try_from(request.selector)?;

        match call_handler_id {
            CallHandlerId::Read => {
                todo!()
            }
            CallHandlerId::Write => {
                todo!()
            }
            CallHandlerId::RootToId => {
                todo!()
            }
            CallHandlerId::IdToRoot => {
                todo!()
            }
        }
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
