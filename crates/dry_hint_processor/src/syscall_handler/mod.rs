pub mod evm;
pub mod injected_state;
pub mod starknet;

use std::{any::Any, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::get_ptr_from_var_name},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use hints::vars;
use syscall_handler::SyscallHandlerWrapper;

pub const SYSCALL_HANDLER_CREATE: &str = "syscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager)";

pub fn syscall_handler_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_handler =
        SyscallHandlerWrapper::<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>::new(
            evm::CallContractHandler::default(),
            starknet::CallContractHandler::default(),
            injected_state::CallContractHandler::default(),
        );
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
    let syscall_handler = exec_scopes.get_mut_ref::<SyscallHandlerWrapper<
        evm::CallContractHandler,
        starknet::CallContractHandler,
        injected_state::CallContractHandler,
    >>(vars::scopes::SYSCALL_HANDLER)?;
    syscall_handler.set_syscall_ptr(syscall_ptr);

    Ok(())
}

pub const ENTER_SCOPE_SYSCALL_HANDLER: &str = "vm_enter_scope({'syscall_handler': syscall_handler})";

pub fn enter_scope_syscall_handler(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_handler: Box<dyn Any> = Box::new(exec_scopes.get::<SyscallHandlerWrapper<
        evm::CallContractHandler,
        starknet::CallContractHandler,
        injected_state::CallContractHandler,
    >>(vars::scopes::SYSCALL_HANDLER)?);
    exec_scopes.enter_scope(HashMap::from_iter([(vars::scopes::SYSCALL_HANDLER.to_string(), syscall_handler)]));

    Ok(())
}
