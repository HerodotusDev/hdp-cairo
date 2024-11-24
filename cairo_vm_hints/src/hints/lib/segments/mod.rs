use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

mod add_segments;

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        add_segments::SEGMENTS_ADD | add_segments::SEGMENTS_ADD_TO_FELT_OR_RELOCATABLE => {
            add_segments::segments_add(vm, exec_scope, hint_data, constants)
        }
        add_segments::SET_FP_PLUS_8_SEGMENTS_ADD => {
            add_segments::set_fp_plus_8_segments_add(vm, exec_scope, hint_data, constants)
        }
        add_segments::SET_FP_PLUS_9_SEGMENTS_ADD => {
            add_segments::set_fp_plus_9_segments_add(vm, exec_scope, hint_data, constants)
        }
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
