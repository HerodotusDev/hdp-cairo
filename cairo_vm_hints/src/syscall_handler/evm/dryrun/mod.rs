#![allow(unused)]
pub mod account;
pub mod header;
pub mod receipt;
pub mod storage;
pub mod transaction;

use crate::cairo_types::traits::CairoType;
use crate::syscall_handler::traits::CallHandler;
use crate::{
    cairo_types::new_syscalls::{CallContractRequest, CallContractResponse},
    syscall_handler::{
        traits::SyscallHandler,
        utils::{felt_from_ptr, SyscallExecutionError, SyscallResult, WriteResponseResult},
    },
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{collections::HashSet, hash::Hash, marker::PhantomData};
use strum_macros::FromRepr;

#[derive(FromRepr)]
pub enum CallHandlerId {
    Header = 0,
    Account = 1,
    Storage = 2,
    Transaction = 3,
    Receipt = 4,
}

#[derive(Debug, Default)]
pub struct CallContractHandler {
    key_set: HashSet<DryRunKey>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.contract_address)?;

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
            CallHandlerId::Header => {
                let key = header::HeaderCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = header::HeaderCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = header::HeaderCallHandler::handle(key, function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <header::HeaderCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            CallHandlerId::Account => {
                let key = account::AccountCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = account::AccountCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = account::AccountCallHandler::handle(key, function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <account::AccountCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            CallHandlerId::Storage => {
                let key = storage::StorageCallHandler::derive_key(vm, &mut calldata)?;
                let function_id = storage::StorageCallHandler::derive_id(request.selector)?;
                println!("key: {:?}, function_id: {:?}", key, function_id);
                let result = storage::StorageCallHandler::handle(key, function_id)?;
                result.to_memory(vm, retdata_end)?;
                retdata_end += <storage::StorageCallHandler as CallHandler>::CallHandlerResult::n_fields();
            }
            _ => {}
        }

        Ok(Self::Response { retdata_start, retdata_end })
    }

    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
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

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
enum DryRunKey {
    Account(account::Key),
    Header(header::Key),
    Storage(storage::Key),
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DryRunKeySet(HashSet<DryRunKey>);
