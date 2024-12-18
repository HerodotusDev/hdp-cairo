use crate::vars;
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    hint_processor::builtin_hint_processor::hint_utils::{get_integer_from_var_name, insert_value_into_ap},
};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{cmp::Ordering, collections::HashMap};

pub const HINT_PROCESSED_WORDS: &str = "memory[ap] = 1 if (ids.value_len - ids.n_processed_words == 0) else 0";

pub fn hint_processed_words(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value_len = get_integer_from_var_name(vars::ids::VALUE_LEN, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let n_processed_words = get_integer_from_var_name(vars::ids::N_PROCESSED_WORDS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = match (value_len - n_processed_words).cmp(&Felt252::ZERO) {
        Ordering::Equal => Felt252::ONE,
        _ => Felt252::ZERO,
    };

    insert_value_into_ap(vm, insert)
}
