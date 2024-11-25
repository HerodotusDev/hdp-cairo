use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
use cairo_vm::{
    any_box,
    hint_processor::{
        builtin_hint_processor::{
            builtin_hint_processor_definition::HintProcessorData, hint_utils::get_ptr_from_var_name,
        },
        hint_processor_definition::HintExtension,
    },
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

use crate::cairo_types::structs::CompiledClass;

use super::scopes::CONTRACT_CLASS;

pub const LOAD_PROGRAM: &str = "vm_load_program(\n    compiled_class.get_runnable_program(entrypoint_builtins=[]),\n    ids.compiled_class.bytecode_ptr\n)";

pub fn load_program(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<HintExtension, HintError> {
    let cairo_lang_class = exec_scopes.get::<CasmContractClass>(CONTRACT_CLASS)?;

    let compiled_class_ptr = get_ptr_from_var_name(
        CONTRACT_CLASS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    let byte_code_ptr =
        vm.get_relocatable((compiled_class_ptr + CompiledClass::bytecode_ptr_offset())?)?;

    let mut hint_extension = HintExtension::new();

    for (rel_pc, hints) in cairo_lang_class.hints.into_iter() {
        let abs_pc: Relocatable = Relocatable::from((byte_code_ptr.segment_index, rel_pc));
        hint_extension.insert(abs_pc, hints.iter().map(|h| any_box!(h.clone())).collect());
    }

    Ok(hint_extension)
}
