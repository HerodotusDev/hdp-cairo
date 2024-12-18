use super::CustomHintProcessor;
use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use hints::vars;
use std::collections::HashMap;
use types::{param::Param, HDPDryRunInput};

pub const HINT_DRY_RUN_INPUT: &str = "from tools.py.schema import HDPDryRunInput\ndry_run_input = HDPDryRunInput.Schema().load(program_input)\nparams = dry_run_input.params\ncompiled_class = dry_run_input.compiled_class";

impl CustomHintProcessor {
    pub fn hint_dry_run_input(
        &mut self,
        _vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        _hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        let hdp_dry_run_input: HDPDryRunInput = serde_json::from_value(self.private_inputs.clone()).map_err(|_| HintError::WrongHintData)?;
        exec_scopes.insert_value::<Vec<Param>>(vars::scopes::PARAMS, hdp_dry_run_input.params);
        exec_scopes.insert_value::<CasmContractClass>(vars::scopes::COMPILED_CLASS, hdp_dry_run_input.compiled_class);
        Ok(())
    }
}
