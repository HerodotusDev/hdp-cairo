use crate::hints;
use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::{
            BuiltinHintProcessor, HintFunc, HintProcessorData,
        },
        hint_processor_definition::HintExtension,
        hint_processor_definition::HintProcessorLogic,
    },
    types::exec_scope::ExecutionScopes,
    vm::{
        errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker,
        vm_core::VirtualMachine,
    },
    Felt252,
};
use starknet_types_core::felt::Felt;
use std::collections::HashMap;
use std::{any::Any, rc::Rc};

#[derive(Default)]
pub struct CustomHintProcessor;

impl CustomHintProcessor {
    pub fn new() -> Self {
        Self {}
    }
}

impl HintProcessorLogic for CustomHintProcessor {
    fn execute_hint(
        &mut self,
        _vm: &mut VirtualMachine,
        _exec_scopes: &mut ExecutionScopes,
        _hint_data: &Box<dyn Any>,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        unreachable!();
    }

    fn execute_hint_extensive(
        &mut self,
        vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        hint_data: &Box<dyn Any>,
        constants: &HashMap<String, Felt>,
    ) -> Result<HintExtension, HintError> {
        let hint_data = hint_data
            .downcast_ref::<HintProcessorData>()
            .ok_or(HintError::WrongHintData)?;

        let res = hints::run_hint(vm, exec_scopes, hint_data, constants);

        if !matches!(res, Err(HintError::UnknownHint(_))) {
            return res.and(Ok(HintExtension::default()));
        }

        hints::run_extensive_hint(vm, exec_scopes, hint_data, constants)
    }
}

impl ResourceTracker for CustomHintProcessor {}
