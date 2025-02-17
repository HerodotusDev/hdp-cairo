use std::{cmp::Ordering, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

use crate::vars;

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

pub const HINT_PROCESSED_WORDS_RLP: &str = "memory[ap] = 1 if (ids.rlp_len - ids.n_processed_words == 0) else 0";

pub fn hint_processed_words_rlp(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let rlp_len = get_integer_from_var_name(vars::ids::RLP_LEN, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let n_processed_words = get_integer_from_var_name(vars::ids::N_PROCESSED_WORDS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = match (rlp_len - n_processed_words).cmp(&Felt252::ZERO) {
        Ordering::Equal => Felt252::ONE,
        _ => Felt252::ZERO,
    };

    insert_value_into_ap(vm, insert)
}
