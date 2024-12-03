use super::utils::{SyscallExecutionError, SyscallHandler, SyscallResult, WriteResponseResult};
use crate::cairo_types::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    traits::CairoType,
};
use cairo_vm::{
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
    Felt252,
};

pub struct CallContractHandler;

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    fn execute(request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let _calldata: Vec<Felt252> = vm
            .get_range(request.calldata_start, (request.calldata_end - request.calldata_start)?)
            .into_iter()
            .map(|f| f.and_then(|f| f.get_int()))
            .collect::<Option<Vec<Felt252>>>()
            .ok_or(SyscallExecutionError::InternalError(
                "Memory error: failed to read full calldata".to_string().into(),
            ))?;

        // SYSCALL HANDLER LOGIC HERE!

        let retdata = vm.add_temporary_segment();
        let data = vec![MaybeRelocatable::from(Felt252::TWO), MaybeRelocatable::from(Felt252::THREE)];
        vm.load_data(retdata, &data)?;
        Ok(Self::Response {
            retdata_start: retdata,
            retdata_end: (retdata + data.len())?,
        })
    }

    fn write_response(response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}
