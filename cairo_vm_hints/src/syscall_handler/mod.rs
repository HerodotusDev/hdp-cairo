pub mod call_contract;
pub mod evm;
pub mod starknet;
pub mod traits;
pub mod utils;

use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
};
use call_contract::CallContractHandler;
use std::{rc::Rc, sync::RwLock};
use utils::{felt_from_ptr, run_handler, SyscallSelector};

/// SyscallHandler implementation for execution of system calls in the StarkNet OS
#[derive(Debug)]
pub struct HDPSyscallHandler {
    syscall_ptr: Option<Relocatable>,
}

/// SyscallHandler is wrapped in Rc<RefCell<_>> in order
/// to clone the reference when entering and exiting vm scopes
#[derive(Debug, Clone)]
pub struct SyscallHandlerWrapper {
    pub syscall_handler: Rc<RwLock<HDPSyscallHandler>>,
}

impl Default for SyscallHandlerWrapper {
    fn default() -> Self {
        Self::new()
    }
}

impl SyscallHandlerWrapper {
    pub fn new() -> Self {
        Self {
            syscall_handler: Rc::new(RwLock::new(HDPSyscallHandler { syscall_ptr: None })),
        }
    }
    pub fn set_syscall_ptr(&self, syscall_ptr: Relocatable) {
        let mut syscall_handler = self.syscall_handler.write().unwrap();
        syscall_handler.syscall_ptr = Some(syscall_ptr);
    }

    pub fn syscall_ptr(&self) -> Option<Relocatable> {
        let syscall_handler = self.syscall_handler.read().unwrap();
        syscall_handler.syscall_ptr
    }

    pub fn execute_syscall(&self, vm: &mut VirtualMachine, syscall_ptr: Relocatable) -> Result<(), HintError> {
        let mut syscall_handler = self.syscall_handler.write().unwrap();
        let ptr = &mut syscall_handler
            .syscall_ptr
            .ok_or(HintError::CustomHint(Box::from("syscall_ptr is None")))?;

        assert_eq!(*ptr, syscall_ptr);

        let selector = SyscallSelector::try_from(felt_from_ptr(vm, ptr)?)?;

        match selector {
            SyscallSelector::CallContract => run_handler::<CallContractHandler>(ptr, vm),
        }?;

        syscall_handler.syscall_ptr = Some(*ptr);

        Ok(())
    }
}
