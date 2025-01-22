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
use types::{param::Param, ChainProofs};

pub const HINT_INPUT: &str = "run_input = HDPInput.Schema().load(program_input)\nchain_proofs = run_input.proofs\nparams = run_input.params\ncompiled_class = run_input.compiled_class";

impl CustomHintProcessor {
    pub fn hint_input(
        &mut self,
        _vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        _hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        exec_scopes.insert_value::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS, self.private_inputs.chain_proofs.to_owned());
        exec_scopes.insert_value::<Vec<Param>>(vars::scopes::PARAMS, self.private_inputs.params.to_owned());
        exec_scopes.insert_value::<CasmContractClass>(vars::scopes::COMPILED_CLASS, self.private_inputs.compiled_class.to_owned());
        Ok(())
    }
}
