use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

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
    let memorizer = get_ptr_from_var_name("evm_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.segment_index))
}

pub const SEGMENTS_ADD_EVM_MEMORIZER_OFFSET: &str = "memory[ap] = to_felt_or_relocatable(ids.evm_memorizer.address_.offset)";

pub fn segments_add_evm_memorizer_offset(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("evm_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.offset))
}

pub const SEGMENTS_ADD_STARKNET_MEMORIZER_INDEX: &str =
    "memory[ap] = to_felt_or_relocatable(ids.starknet_memorizer.address_.segment_index)";

pub fn segments_add_starknet_memorizer_index(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("starknet_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.segment_index))
}

pub const SEGMENTS_ADD_STARKNET_MEMORIZER_OFFSET: &str = "memory[ap] = to_felt_or_relocatable(ids.starknet_memorizer.address_.offset)";

pub fn segments_add_starknet_memorizer_offset(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("starknet_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.offset))
}

pub const SEGMENTS_ADD_INJECTED_STATE_MEMORIZER_INDEX: &str =
    "memory[ap] = to_felt_or_relocatable(ids.injected_state_memorizer.address_.segment_index)";

pub fn segments_add_injected_state_memorizer_index(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("injected_state_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.segment_index))
}

pub const SEGMENTS_ADD_INJECTED_STATE_MEMORIZER_OFFSET: &str =
    "memory[ap] = to_felt_or_relocatable(ids.injected_state_memorizer.address_.offset)";

pub fn segments_add_injected_state_memorizer_offset(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("injected_state_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.offset))
}

pub const SEGMENTS_ADD_UNCONSTRAINED_MEMORIZER_INDEX: &str =
    "memory[ap] = to_felt_or_relocatable(ids.unconstrained_memorizer.address_.segment_index)";

pub fn segments_add_unconstrained_memorizer_index(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("unconstrained_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.segment_index))
}

pub const SEGMENTS_ADD_UNCONSTRAINED_MEMORIZER_OFFSET: &str =
    "memory[ap] = to_felt_or_relocatable(ids.unconstrained_memorizer.address_.offset)";

pub fn segments_add_unconstrained_memorizer_offset(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memorizer = get_ptr_from_var_name("unconstrained_memorizer", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_into_ap(vm, Felt252::from(memorizer.offset))
}

pub const MMR_METAS_LEN_COUNTER: &str = "memory[ap] = 1 if (ids.mmr_metas_len == ids.counter) else 0";

pub fn mmr_metas_len_counter(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let mmr_metas_len = get_integer_from_var_name("mmr_metas_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let counter = get_integer_from_var_name("counter", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if mmr_metas_len == counter { Felt252::ONE } else { Felt252::ZERO };

    insert_value_into_ap(vm, insert)
}

pub const RETDATA_SIZE_COUNTER: &str = "memory[ap] = 1 if (ids.retdata_size == ids.counter) else 0";

pub fn retdata_size_counter(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let retdata_size = get_integer_from_var_name("retdata_size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let counter = get_integer_from_var_name("counter", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if retdata_size == counter { Felt252::ONE } else { Felt252::ZERO };
    println!("{}", retdata_size);
    println!("{}", counter);
    insert_value_into_ap(vm, insert)
}
