use cairo_vm::{
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use hints::vars;
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{felt_from_ptr, run_handler, traits, SyscallExecutionError, SyscallResult, SyscallSelector, WriteResponseResult};
use tokio::{sync::RwLock, task};
use types::cairo::{new_syscalls::{CallContractRequest, CallContractResponse}, traits::CairoType};

#[derive(FromRepr)]
pub enum CallHandlerId {
    Print = 0,
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct DebugHandler;

impl traits::SyscallHandler for DebugHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let call_handler_id = CallHandlerId::try_from(request.selector)?;
        match call_handler_id {
            CallHandlerId::Print => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();
                
                // Print single value without array notation if length is 1
                if fields.len() == 1 {
                    println!("{}", fields[0]);
                } else {
                    println!("{:?}", fields);
                }
                Ok(Self::Response { retdata_start: request.calldata_end, retdata_end: request.calldata_end })
            }
        }
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        Ok(())
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