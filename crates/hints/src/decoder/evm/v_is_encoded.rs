use std::{cmp::Ordering, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_relocatable_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

const FELT_127: Felt252 = Felt252::from_hex_unchecked("0x7f");

pub const HINT_V_IS_ENCODED: &str = "if ids.v.low <= 0x7f:\n    ids.v_is_encoded = 0\nelse:\n    ids.v_is_encoded = 1";

pub fn hint_v_is_encoded(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let v_ptr = get_relocatable_from_var_name("v", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let v = vm
        .get_continuous_range(v_ptr, 2)?
        .into_iter()
        .map(|v| v.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let insert = match v[0].cmp(&FELT_127) {
        Ordering::Less | Ordering::Equal => Felt252::ZERO,
        Ordering::Greater => Felt252::ONE,
    };

    insert_value_from_var_name(
        "v_is_encoded",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
