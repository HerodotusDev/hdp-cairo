use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_integer_from_var_name, insert_value_from_var_name,
};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::MaybeRelocatable;
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use std::cmp::Ordering;
use std::collections::HashMap;

const HINT_IS_BYZANTIUM: &str =
    "ids.is_byzantium = 1 if ids.block_number >= ids.chain_info.byzantium else 0";

const BYZANTIUM_START_BLOCK_NUMBER: Felt252 = Felt252::from_hex_unchecked("0x42AE50");

fn hint_is_byzantium(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match get_integer_from_var_name(
        "block_number",
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?
    .cmp(&BYZANTIUM_START_BLOCK_NUMBER)
    {
        Ordering::Less => insert_value_from_var_name(
            "is_byzantium",
            MaybeRelocatable::Int(Felt252::ZERO),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        )?,
        Ordering::Equal | Ordering::Greater => insert_value_from_var_name(
            "is_byzantium",
            MaybeRelocatable::Int(Felt252::ONE),
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        )?,
    };

    Ok(())
}

pub fn run_hint(
    vm: &mut VirtualMachine,
    exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    match hint_data.code.as_str() {
        HINT_IS_BYZANTIUM => hint_is_byzantium(vm, exec_scope, hint_data, constants),
        _ => Err(HintError::UnknownHint(
            hint_data.code.to_string().into_boxed_str(),
        )),
    }
}
