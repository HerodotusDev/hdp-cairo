use super::utils::{SyscallHandler, SyscallResult, WriteResponseResult};
use crate::cairo_types::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    traits::CairoType,
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};

pub struct CallContractHandler;

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    fn execute(_request: Self::Request, _vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        Ok(Self::Response {
            retdata_start: Felt252::from(0_u32),
            retdata_end: Felt252::from(1_u32),
        })
    }

    fn write_response(
        response: Self::Response,
        vm: &mut VirtualMachine,
        ptr: &mut Relocatable,
    ) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}
