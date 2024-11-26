use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData, hint_utils::get_integer_from_var_name,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const PROGRAM_HASH: &str = "print(\"program_hash\", hex(ids.program_hash))";

pub fn program_hash(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!(
        "program_hash: {}",
        get_integer_from_var_name(
            "program_hash",
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking
        )?
    );
    Ok(())
}
