use std::collections::HashMap;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use hints::vars;
use types::param;

use super::CustomHintProcessor;

pub const HINT_INPUT: &str =
    "dry_run_input = HDPDryRunInput.Schema().load(program_input)\nparams = dry_run_input.params\ncompiled_class = dry_run_input.compiled_class";

impl CustomHintProcessor {
    pub fn hint_input(
        &mut self,
        _vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        _hint_data: &HintProcessorData,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        exec_scopes.insert_value::<Vec<Felt252>>(
            vars::scopes::PUBLIC_INPUTS,
            self.inputs
                .params
                .iter()
                .filter_map(|f| match f.visibility {
                    param::Visibility::Public => Some(f.value),
                    param::Visibility::Private => None,
                })
                .collect(),
        );
        exec_scopes.insert_value::<Vec<Felt252>>(
            vars::scopes::PRIVATE_INPUTS,
            self.inputs
                .params
                .iter()
                .filter_map(|f| match f.visibility {
                    param::Visibility::Private => Some(f.value),
                    param::Visibility::Public => None,
                })
                .collect(),
        );
        exec_scopes.insert_value::<CasmContractClass>(vars::scopes::COMPILED_CLASS, self.inputs.compiled_class.to_owned());
        Ok(())
    }
}
