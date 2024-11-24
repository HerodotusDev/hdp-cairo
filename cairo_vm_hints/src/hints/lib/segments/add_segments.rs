use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData, hint_utils::insert_value_into_ap,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

pub const SEGMENTS_ADD: &str = "memory[ap] = segments.add()";
pub const SEGMENTS_ADD_TO_FELT_OR_RELOCATABLE: &str =
    "memory[ap] = to_felt_or_relocatable(segments.add())";

pub fn segments_add(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let segment = vm.add_memory_segment();
    insert_value_into_ap(vm, segment)
}

pub const SET_FP_PLUS_8_SEGMENTS_ADD: &str =
    "memory[fp + 8] = to_felt_or_relocatable(segments.add())";

pub fn set_fp_plus_8_segments_add(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let segment = vm.add_memory_segment();
    Ok(vm.insert_value((vm.get_fp() + 8)?, segment)?)
}

pub const SET_FP_PLUS_9_SEGMENTS_ADD: &str =
    "memory[fp + 9] = to_felt_or_relocatable(segments.add())";

pub fn set_fp_plus_9_segments_add(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let segment = vm.add_memory_segment();
    Ok(vm.insert_value((vm.get_fp() + 9)?, segment)?)
}
