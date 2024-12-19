use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_relocatable_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const SEGMENTS_ADD: &str = "memory[ap] = to_felt_or_relocatable(segments.add())";

pub fn segments_add(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let segment = vm.add_memory_segment();
    insert_value_into_ap(vm, segment)
}

pub const SEGMENTS_ADD_FP: &str = "memory[fp + 0] = to_felt_or_relocatable(segments.add())";
pub fn segments_add_fp(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let segment = vm.add_memory_segment();
    vm.insert_value((vm.get_fp() + 0)?, segment)?;
    Ok(())
}

pub const SEGMENTS_ADD_EVM_MEMORIZER_SEGMENT_INDEX: &str = "memory[ap] = to_felt_or_relocatable(ids.evm_memorizer.address_.segment_index)";

pub fn segments_add_evm_memorizer_segment_index(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_relocatable_from_var_name("evm_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.segment_index))
}

pub const SEGMENTS_ADD_EVM_MEMORIZER_OFFSET: &str = "memory[ap] = to_felt_or_relocatable(ids.evm_memorizer.address_.offset)";

pub fn segments_add_evm_memorizer_offset(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_relocatable_from_var_name("evm_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.offset))
}

pub const SEGMENTS_ADD_EVM_STARKNET_MEMORIZER_INDEX: &str = "memory[ap] = to_felt_or_relocatable(ids.starknet_memorizer.address_.segment_index)";

pub fn segments_add_evm_starknet_memorizer_index(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_relocatable_from_var_name("starknet_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.segment_index))
}

pub const SEGMENTS_ADD_STARKNET_MEMORIZER_OFFSET: &str = "memory[ap] = to_felt_or_relocatable(ids.starknet_memorizer.address_.offset)";

pub fn segments_add_starknet_memorizer_offset(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_relocatable_from_var_name("starknet_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.offset))
}
