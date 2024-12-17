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
use types::{param::Param, proofs::Proofs, HDPInput};

pub const HINT_RUN_INPUT: &str = "from tools.py.schema import HDPInput\nrun_input = HDPInput.Schema().load(program_input)\nproofs = run_input.proofs\nparams = run_input.params\ncompiled_class = run_input.compiled_class";

impl CustomHintProcessor {
    pub fn hint_run_input(
        &mut self,
        _vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        _hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        let hdp_input: HDPInput = serde_json::from_value(self.private_inputs.clone()).map_err(|_| HintError::WrongHintData)?;
        exec_scopes.insert_value::<Vec<Proofs>>(vars::scopes::PROOFS, hdp_input.proofs);
        exec_scopes.insert_value::<Vec<Param>>(vars::scopes::PARAMS, hdp_input.params);
        exec_scopes.insert_value::<CasmContractClass>(vars::scopes::COMPILED_CLASS, hdp_input.compiled_class);
        Ok(())
    }
}
