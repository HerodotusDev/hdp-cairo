use std::{cell::RefCell, collections::HashMap, rc::Rc};

use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::{
            builtin_hint_processor_definition::HintProcessorData,
            hint_utils::{get_address_from_var_name, get_ptr_from_var_name},
        },
        hint_processor_utils::get_integer_from_reference,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use crate::syscall_handler::SyscallHandlerWrapper;

use super::scopes::{SYSCALL_HANDLER, SYSCALL_PTR};

pub const SYSCALL_HANDLER_CREATE: &str = "if 'syscall_handler' not in globals():\n    from contract_bootloader.syscall_handler import SyscallHandler\n    if '__dict_manager' not in globals():\n        from starkware.cairo.common.dict import DictManager\n        __dict_manager = DictManager()\n    syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager)\n\nids.syscall_ptr = segments.add()\nsyscall_handler.set_syscall_ptr(syscall_ptr=ids.syscall_ptr)";

pub fn syscall_handler_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    if let Err(HintError::VariableNotInScopeError(_)) =
        exec_scopes.get::<SyscallHandlerWrapper>(SYSCALL_HANDLER)
    {
        let syscall_handler = SyscallHandlerWrapper::new();
        exec_scopes.insert_value(SYSCALL_HANDLER, Rc::new(RefCell::new(syscall_handler)));
    }

    Ok(())
}

pub const SYSCALL_HANDLER_SET_SYSCALL_PTR: &str =
    "syscall_handler.set_syscall_ptr(syscall_ptr=ids.syscall_ptr)";

pub fn syscall_handler_set_syscall_ptr(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_ptr =
        get_ptr_from_var_name(SYSCALL_PTR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let syscall_handler = exec_scopes.get::<SyscallHandlerWrapper>(SYSCALL_HANDLER)?;
    syscall_handler.set_syscall_ptr(syscall_ptr);

    Ok(())
}
