use crate::vars;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, dict_manager::DictManager},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{cell::RefCell, collections::HashMap, rc::Rc};

pub const DICT_MANAGER_CREATE: &str =
    "if '__dict_manager' not in globals():\n    from starkware.cairo.common.dict import DictManager\n    __dict_manager = DictManager()";

pub fn dict_manager_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    if let Err(HintError::VariableNotInScopeError(_)) = exec_scopes.get_dict_manager() {
        let dict_manager = DictManager::new();
        exec_scopes.insert_value(vars::scopes::DICT_MANAGER, Rc::new(RefCell::new(dict_manager)));
    }

    Ok(())
}
