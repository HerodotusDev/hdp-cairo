use std::collections::HashMap;

use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
        hint_processor_definition::HintExtension,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

pub mod cairo_types;
pub mod dict_manager;
pub mod program;
pub mod scopes;
pub mod syscall;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        scopes::ENTER_SCOPE_SYSCALL_HANDLER => {
            scopes::enter_scope_syscall_handler(vm, exec_scopes, hint_data, constants)
        }
        scopes::EXIT_SCOPE => scopes::exit_scope(vm, exec_scopes, hint_data, constants),
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}

pub fn run_extensive_hint(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<HintExtension, HintError> {
    match hint_data.code.as_str() {
        program::LOAD_PROGRAM => program::load_program(vm, exec_scopes, hint_data, constants),
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
