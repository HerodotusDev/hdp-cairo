use crate::vars;
use cairo_vm::hint_processor::builtin_hint_processor::{
    builtin_hint_processor_definition::HintProcessorData, hint_utils::get_relocatable_from_var_name,
};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use std::collections::HashMap;

pub const HINT_PRINT_TASK_RESULT: &str = "print(f\"Task Result: {hex(ids.result.high * 2 ** 128 + ids.result.low)}\")";

pub fn hint_print_task_result(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let result_ptr = get_relocatable_from_var_name(vars::ids::RESULT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let result = vm
        .get_continuous_range(result_ptr, 2)?
        .into_iter()
        .map(|v| v.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let result_low = result[0].to_biguint();
    let result_high = result[1].to_biguint();
    let base = BigUint::from(2u32).pow(128);

    let result_value = result_high * base + result_low;

    // TODO: add appropriate logger
    println!("Task Result: 0x{:x}", result_value);

    Ok(())
}