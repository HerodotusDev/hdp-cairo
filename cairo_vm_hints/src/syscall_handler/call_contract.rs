use super::{
    evm,
    traits::CallHandler,
    utils::{felt_from_ptr, SyscallExecutionError, SyscallHandler, SyscallResult, WriteResponseResult},
};
use crate::cairo_types::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    traits::CairoType,
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};

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
        let mut calldata = request.calldata_start;

        let call_handler_id = evm::dryrun::CallHandlerId::try_from(request.contract_address)?;

        let segment_index = felt_from_ptr(vm, &mut calldata)?;
        let offset = felt_from_ptr(vm, &mut calldata)?;

        let _memorizer = Relocatable::from((
            segment_index
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            offset
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
        ));

        let retdata_start = vm.add_temporary_segment();
        let mut retdata_end = retdata_start;

        match call_handler_id {
            evm::dryrun::CallHandlerId::Header => {
                let key = evm::dryrun::header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = evm::dryrun::header::HeaderCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = evm::dryrun::header::HeaderCallHandler::handle(key, function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <evm::dryrun::header::HeaderCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            evm::dryrun::CallHandlerId::Account => {
                let key = evm::dryrun::account::AccountCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = evm::dryrun::account::AccountCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = evm::dryrun::account::AccountCallHandler::handle(key, function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <evm::dryrun::account::AccountCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            evm::dryrun::CallHandlerId::Storage => {
                let key = evm::dryrun::storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = evm::dryrun::storage::StorageCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = evm::dryrun::storage::StorageCallHandler::handle(key, function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <evm::dryrun::storage::StorageCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            _ => {}
        }

        Ok(Self::Response { retdata_start, retdata_end })
    }

    fn write_response(response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}
