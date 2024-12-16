use crate::{hints::vars, syscall_handler::evm::dryrun::SyscallHandlerWrapper};
use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::get_ptr_from_var_name},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const SYSCALL_HANDLER_CREATE: &str = "if 'syscall_handler' not in globals():\n    from contract_bootloader.syscall_handler import SyscallHandler\n    syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager)";

pub fn syscall_handler_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    if let Err(HintError::VariableNotInScopeError(_)) = exec_scopes.get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER) {
        let syscall_handler = SyscallHandlerWrapper::new();
        exec_scopes.insert_value(vars::scopes::SYSCALL_HANDLER, syscall_handler);
    }

    Ok(())
}

pub const DRY_RUN_SYSCALL_HANDLER_CREATE: &str = "from contract_bootloader.dryrun_syscall_handler import DryRunSyscallHandler\nsyscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager)";

pub fn dry_run_syscall_handler_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_handler = SyscallHandlerWrapper::new();
    exec_scopes.insert_value(vars::scopes::SYSCALL_HANDLER, syscall_handler);

    Ok(())
}

pub const SYSCALL_HANDLER_SET_SYSCALL_PTR: &str = "syscall_handler.set_syscall_ptr(syscall_ptr=ids.syscall_ptr)";

pub fn syscall_handler_set_syscall_ptr(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_ptr = get_ptr_from_var_name(vars::ids::SYSCALL_PTR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let syscall_handler = exec_scopes.get_mut_ref::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)?;
    syscall_handler.set_syscall_ptr(syscall_ptr);

    Ok(())
}
