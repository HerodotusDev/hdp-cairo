use crate::hints::vars;

use super::CustomHintProcessor;
use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const HINT_INPUT: &str = "from tools.py.schema import HDPDryRunInput\ncompiled_class = HDPDryRunInput.Schema().load(program_input).modules[0].module_class";

impl CustomHintProcessor {
    pub fn hint_input(
        &mut self,
        _vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        _hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        let contract_class: CasmContractClass =
            serde_json::from_value(self.private_inputs[vars::scopes::COMPILED_CLASS].clone())
                .map_err(|_| HintError::WrongHintData)?;
        exec_scopes.insert_value::<CasmContractClass>(vars::scopes::COMPILED_CLASS, contract_class);
        Ok(())
    }
}
