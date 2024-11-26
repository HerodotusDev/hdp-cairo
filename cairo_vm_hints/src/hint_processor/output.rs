use super::CustomHintProcessor;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::get_relocatable_from_var_name,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const HINT_OUTPUT: &str =
    "print(\"result.low\", hex(ids.result.low))\nprint(\"result.high\", hex(ids.result.high))";

impl CustomHintProcessor {
    pub fn hint_output(
        &mut self,
        vm: &mut VirtualMachine,
        _exec_scopes: &mut ExecutionScopes,
        hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        let result_ptr = get_relocatable_from_var_name(
            "result",
            vm,
            &hint_data.ids_data,
            &hint_data.ap_tracking,
        )?;

        let result = vm
            .get_continuous_range(result_ptr, 2)?
            .into_iter()
            .map(|v| v.get_int().unwrap())
            .collect::<Vec<Felt252>>();

        println!("result.low: {}", result[0]);
        println!("result.high: {}", result[1]);
        Ok(())
    }
}
