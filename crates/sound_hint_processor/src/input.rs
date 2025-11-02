use std::collections::HashMap;

use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use hints::vars;
use types::{param, proofs::injected_state::StateProofs, ChainProofs, InjectedState, UnconstrainedState};

use super::CustomHintProcessor;

pub const HINT_INPUT: &str = "run_input = HDPInput.Schema().load(program_input)\nparams = run_input.params\ncompiled_class = run_input.compiled_class\ninjected_state = run_input.injected_state\nchain_proofs = run_input.proofs_data.chain_proofs\nstate_proofs = run_input.proofs_data.state_proofs";

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
        exec_scopes.insert_value::<InjectedState>(vars::scopes::INJECTED_STATE, self.inputs.injected_state.to_owned());
        exec_scopes.insert_value::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS, self.inputs.chain_proofs.to_owned());
        exec_scopes.insert_value::<StateProofs>(vars::scopes::STATE_PROOFS, self.inputs.state_proofs.to_owned());
        exec_scopes.insert_value::<UnconstrainedState>(vars::scopes::UNCONSTRAINED_STATE, self.inputs.unconstrained.to_owned());
        Ok(())
    }
}
