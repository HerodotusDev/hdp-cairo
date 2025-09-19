use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use starknet_crypto::poseidon_hash_many;
use types::{cairo::injected_state::LABEL_RUNTIME, InjectedState};

use crate::vars;

pub const LOAD_PUBLIC_INPUTS: &str = "segments.write_arg(ids.public_inputs, public_inputs)";
pub const LOAD_PUBLIC_INPUTS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(public_inputs))";
pub const LOAD_PRIVATE_INPUTS: &str = "segments.write_arg(ids.private_inputs, private_inputs)";
pub const LOAD_PRIVATE_INPUTS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(private_inputs))";

pub fn load_public_inputs(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PUBLIC_INPUTS)?;
    let inputs_base = get_ptr_from_var_name(vars::ids::PUBLIC_INPUTS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.load_data(inputs_base, &inputs.iter().map(MaybeRelocatable::from).collect::<Vec<_>>())?;
    Ok(())
}

pub fn load_public_inputs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PUBLIC_INPUTS)?;
    insert_value_into_ap(vm, inputs.len())?;
    Ok(())
}

pub fn load_private_inputs(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PRIVATE_INPUTS)?;
    let inputs_base = get_ptr_from_var_name(vars::ids::PRIVATE_INPUTS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.load_data(inputs_base, &inputs.iter().map(MaybeRelocatable::from).collect::<Vec<_>>())?;
    Ok(())
}

pub fn load_private_inputs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let inputs = exec_scopes.get::<Vec<Felt252>>(vars::scopes::PRIVATE_INPUTS)?;
    insert_value_into_ap(vm, inputs.len())?;
    Ok(())
}

pub const INJECTED_STATES_ENTRIES_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(injected_states.entries()))";

pub fn injected_states_entries_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let injected_states = exec_scopes.get::<InjectedState>(vars::scopes::INJECTED_STATE)?;
    insert_value_into_ap(vm, injected_states.0.len())
}

pub const INJECTED_STATES_WRITE_LISTS: &str = "segments.write_arg(ids.injected_state_keys, injected_states.keys())\nsegments.write_arg(ids.injected_state_values, injected_states.values())";

pub fn injected_states_write_lists(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let injected_states = exec_scopes.get::<InjectedState>(vars::scopes::INJECTED_STATE)?;
    let injected_state_keys_ptr = get_ptr_from_var_name("injected_state_keys", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let injected_state_values_ptr = get_ptr_from_var_name("injected_state_values", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let (keys, values): (Vec<Felt252>, Vec<Felt252>) = injected_states.0.into_iter().unzip();
    vm.load_data(
        injected_state_keys_ptr,
        &keys.iter().map(MaybeRelocatable::from).collect::<Vec<_>>(),
    )?;
    vm.load_data(
        injected_state_values_ptr,
        &values.iter().map(MaybeRelocatable::from).collect::<Vec<_>>(),
    )?;
    Ok(())
}

pub const INJECTED_STATES_SET_KEYS: &str =
    "injected_state_memorizer.set_key(poseidon_hash_many(LABEL_RUNTIME, key), value) for (key, value) in injected_states";

pub fn injected_states_set_keys(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let dict_manager = exec_scopes.get_dict_manager()?;
    let injected_states = exec_scopes.get::<InjectedState>(vars::scopes::INJECTED_STATE)?;
    let injected_state_memorizer_ptr =
        get_ptr_from_var_name(vars::ids::INJECTED_STATE_MEMORIZER, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    for (key, val) in injected_states.0 {
        dict_manager
            .borrow_mut()
            .get_tracker_mut(injected_state_memorizer_ptr)?
            .insert_value(
                &MaybeRelocatable::Int(poseidon_hash_many(&[LABEL_RUNTIME, key])),
                &MaybeRelocatable::Int(val),
            );
    }

    Ok(())
}
