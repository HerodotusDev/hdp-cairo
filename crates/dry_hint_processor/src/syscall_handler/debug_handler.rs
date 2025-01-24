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
use types::cairo::{new_syscalls::CallDebuggerRequest, traits::CairoType};

#[derive(FromRepr)]
pub enum CallHandlerId {
    Print = 0,
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct DebugHandler;

impl traits::SyscallHandler for DebugHandler {
    type Request = CallDebuggerRequest;

    type Response = ();

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let calldata_ptr = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.selector)?;
        let calldata_length = request.calldata_length;

        match call_handler_id {
            CallHandlerId::Print => {
                let fields = vm
                    .get_integer_range(calldata_ptr, calldata_length.try_into().unwrap())?
                    .into_iter()
                    .map(|f| (*f.as_ref()))
                    .collect::<Vec<Felt252>>();
                for (i, field) in fields.iter().enumerate() {
                    println!("[{}]: {}", i, field);
                }
                Ok(())
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