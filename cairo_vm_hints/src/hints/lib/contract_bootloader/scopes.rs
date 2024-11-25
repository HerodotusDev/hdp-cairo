use std::{any::Any, collections::HashMap};

use crate::syscall_handler::SyscallHandlerWrapper;
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

pub const DICT_MANAGER: &str = "dict_manager";
pub const SYSCALL_HANDLER: &str = "syscall_handler";
pub const CONTRACT_CLASS: &str = "syscall_handler";
pub const SYSCALL_PTR: &str = "syscall_ptr";

pub const ENTER_SCOPE_SYSCALL_HANDLER: &str =
    "vm_enter_scope({'syscall_handler': syscall_handler})";

pub fn enter_scope_syscall_handler(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let sys = exec_scopes.get::<SyscallHandlerWrapper>(SYSCALL_HANDLER)?;
    let syscall_handler: Box<dyn Any> = Box::new(sys);
    exec_scopes.enter_scope(HashMap::from_iter([(
        SYSCALL_HANDLER.to_string(),
        syscall_handler,
    )]));
    Ok(())
}

pub const EXIT_SCOPE: &str = "vm_exit_scope()";

pub fn exit_scope(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    exec_scopes.exit_scope().map_err(HintError::FromScopeError)
}
