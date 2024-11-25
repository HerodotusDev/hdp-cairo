use super::utils::{SyscallHandler, SyscallResult, WriteResponseResult};
use crate::cairo_types::new_syscalls::{CallContractRequest, CallContractResponse};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};

pub struct CallContractHandler;

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(_vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        todo!()
    }

    fn execute(request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        todo!()
    }

    fn write_response(
        response: Self::Response,
        vm: &mut VirtualMachine,
        ptr: &mut Relocatable,
    ) -> WriteResponseResult {
        todo!()
    }
}
