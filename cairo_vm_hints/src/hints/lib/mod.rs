use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub mod contract_bootloader;
pub mod segments;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let hints = [segments::run_hint];

    for hint in hints.iter() {
        let res = hint(vm, exec_scope, hint_data, constants);
        if !matches!(res, Err(HintError::UnknownHint(_))) {
            return res;
        }
    }
    Err(HintError::UnknownHint(
        hint_data.code.to_string().into_boxed_str(),
    ))
}
