use super::utils::{SyscallHandler, SyscallResult, WriteResponseResult};
use crate::cairo_types::new_syscalls::{CallContractRequest, CallContractResponse};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};

pub struct CallContractHandler;

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(_vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        todo!()
    }

    fn execute(_request: Self::Request, _vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        todo!()
    }

    fn write_response(
        _response: Self::Response,
        _vm: &mut VirtualMachine,
        _ptr: &mut Relocatable,
    ) -> WriteResponseResult {
        todo!()
    }
}
