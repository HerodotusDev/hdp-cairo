use super::utils::{ReadOnlySegment, SyscallResult, WriteResponseResult};
use crate::hints::lib::contract_bootloader::syscall::utils::{
    felt_from_ptr, run_handler, SyscallSelector,
};
use crate::hints::lib::contract_bootloader::{
    cairo_types::new_syscalls::{CallContractRequest, CallContractResponse},
    syscall::utils::SyscallHandler,
};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
};
use std::{rc::Rc, sync::RwLock};

/// Represents read-only segments dynamically allocated during execution.
#[derive(Debug, Default)]
pub struct ReadOnlySegments(Vec<ReadOnlySegment>);

/// SyscallHandler implementation for execution of system calls in the StarkNet OS
#[derive(Debug)]
pub struct HDPSyscallHandler {
    pub syscall_ptr: Option<Relocatable>,
    pub segments: ReadOnlySegments,
}

/// SyscallHandler is wrapped in Rc<RefCell<_>> in order
/// to clone the reference when entering and exiting vm scopes
#[derive(Debug)]
pub struct SyscallHandlerWrapper {
    pub syscall_handler: Rc<RwLock<HDPSyscallHandler>>,
}

impl Clone for SyscallHandlerWrapper {
    fn clone(&self) -> Self {
        Self {
            syscall_handler: self.syscall_handler.clone(),
        }
    }
}

impl SyscallHandlerWrapper {
    pub fn new() -> Self {
        Self {
            syscall_handler: Rc::new(RwLock::new(HDPSyscallHandler {
                syscall_ptr: None,
                segments: ReadOnlySegments::default(),
            })),
        }
    }
    pub async fn set_syscall_ptr(&self, syscall_ptr: Relocatable) {
        let mut syscall_handler = self.syscall_handler.write().unwrap();
        syscall_handler.syscall_ptr = Some(syscall_ptr);
    }

    pub async fn syscall_ptr(&self) -> Option<Relocatable> {
        let syscall_handler = self.syscall_handler.read().unwrap();
        syscall_handler.syscall_ptr
    }

    pub async fn execute_syscall(
        &self,
        vm: &mut VirtualMachine,
        syscall_ptr: Relocatable,
    ) -> Result<(), HintError> {
        let mut syscall_handler = self.syscall_handler.write().unwrap();
        let ptr = &mut syscall_handler
            .syscall_ptr
            .ok_or(HintError::CustomHint(Box::from("syscall_ptr is None")))?;

        assert_eq!(*ptr, syscall_ptr);

        let selector = SyscallSelector::try_from(felt_from_ptr(vm, ptr)?)?;

        match selector {
            SyscallSelector::CallContract => run_handler::<CallContractHandler>(ptr, vm).await,
            _ => Err(HintError::CustomHint(
                format!("Unknown syscall selector: {:?}", selector).into(),
            )),
        }?;

        syscall_handler.syscall_ptr = Some(*ptr);

        Ok(())
    }
}

struct CallContractHandler;

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(_vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        todo!()
    }

    async fn execute(
        request: Self::Request,
        vm: &mut VirtualMachine,
    ) -> SyscallResult<Self::Response> {
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