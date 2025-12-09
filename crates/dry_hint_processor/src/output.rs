use std::collections::HashMap;
use std::borrow::Cow;

use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::{
            builtin_hint_processor_definition::HintProcessorData,
            hint_utils::{get_integer_from_var_name, get_relocatable_from_var_name},
        },
        hint_processor_utils::felt_to_usize,
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{
        errors::{hint_errors::HintError, memory_errors::MemoryError},
        vm_core::VirtualMachine,
    },
    Felt252,
};
use hints::vars;
use serde_json;

use super::CustomHintProcessor;

pub const HINT_OUTPUT: &str = "print(\"result\", [hex(ids.result.low), hex(ids.result.high)])";
pub const HINT_SAVE_OUTPUT_PREIMAGE: &str = "save_output_preimage(ids.retdata, ids.retdata_size)";

impl CustomHintProcessor {
    pub fn hint_output(
        &mut self,
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

        println!("result: {}, {}", result[0], result[1]);
        Ok(())
    }

    pub fn hint_save_output_preimage(
        &mut self,
        vm: &mut VirtualMachine,
        _exec_scopes: &mut ExecutionScopes,
        hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        let retdata_ptr = get_relocatable_from_var_name("retdata", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
        let retdata_size = get_integer_from_var_name("retdata_size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
        let len = felt_to_usize(&retdata_size)?;

        let values = vm
            .get_continuous_range(retdata_ptr, len)?
            .into_iter()
            .map(|value| {
                match value {
                    MaybeRelocatable::Int(felt) => {
                        println!("hit reloacatable int: {}", felt);
                        Ok(felt)
                    },
                    MaybeRelocatable::RelocatableValue(relocatable) => {
                        println!(
                            "hit relocatable, dereferencing: segment_index={}, offset={}",
                            relocatable.segment_index, relocatable.offset
                        );
        
                        // Deref pointer and expect an integer at that address
                        let inner: Cow<'_, Felt252> = vm
                            .get_integer(relocatable)
                            .map_err(HintError::Memory)?;

                        Ok(inner.into_owned())
                    }
                }
            })
            .collect::<Result<Vec<Felt252>, HintError>>()?;

        // Write directly to file using the path stored in the hint processor
        let json_bytes = serde_json::to_vec(&values)
            .map_err(|e| HintError::CustomHint(format!("Failed to serialize output preimage: {}", e).into_boxed_str()))?;
        std::fs::write(&self.output_preimage_path, json_bytes).map_err(|e| {
            HintError::CustomHint(
                format!("Failed to write output preimage to {}: {}", self.output_preimage_path.display(), e).into_boxed_str(),
            )
        })?;

        Ok(())
    }
}