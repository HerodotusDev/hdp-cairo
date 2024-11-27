use cairo_lang_starknet_classes::casm_contract_class::{CasmContractClass, CasmContractEntryPoint};
use cairo_vm::{
    hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData,
    types::{
        exec_scope::ExecutionScopes,
        relocatable::{MaybeRelocatable, Relocatable},
    },
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

use crate::hints::vars;

const COMPILED_CLASS_V1: Felt252 =
    Felt252::from_hex_unchecked("0x434f4d50494c45445f434c4153535f5631");

pub const LOAD_CONTRACT_CLASS: &str = "from contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct\nids.compiled_class = segments.gen_arg(get_compiled_class_struct(compiled_class=compiled_class))";

pub fn load_contract_class(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let contract_class = exec_scopes.get::<CasmContractClass>(vars::scopes::COMPILED_CLASS)?;
    let class_base = vm.add_memory_segment();
    write_class(vm, class_base, contract_class)?;
    Ok(())
}

pub fn write_class(
    vm: &mut VirtualMachine,
    ptr: Relocatable,
    contract_class: CasmContractClass,
) -> Result<(), HintError> {
    vm.insert_value(ptr, COMPILED_CLASS_V1)?;

    load_casm_entrypoints(
        vm,
        (ptr + 1)?,
        &contract_class.entry_points_by_type.external,
    )?;
    load_casm_entrypoints(
        vm,
        (ptr + 3)?,
        &contract_class.entry_points_by_type.l1_handler,
    )?;
    load_casm_entrypoints(
        vm,
        (ptr + 5)?,
        &contract_class.entry_points_by_type.constructor,
    )?;

    let bytecode: Vec<_> = contract_class
        .bytecode
        .iter()
        .map(|x| x.value.clone())
        .collect();

    let data: Vec<MaybeRelocatable> = bytecode
        .into_iter()
        .map(Felt252::from)
        .map(MaybeRelocatable::from)
        .collect();
    vm.insert_value((ptr + 7)?, Felt252::from(data.len()))?;
    let data_base = vm.add_memory_segment();
    vm.load_data(data_base, &data)?;
    vm.insert_value((ptr + 8)?, data_base)?;
    Ok(())
}

fn load_casm_entrypoints(
    vm: &mut VirtualMachine,
    base: Relocatable,
    entry_points: &[CasmContractEntryPoint],
) -> Result<(), HintError> {
    let mut b: Vec<MaybeRelocatable> = Vec::new();
    for ep in entry_points.iter() {
        b.push(MaybeRelocatable::from(Felt252::from(&ep.selector)));
        b.push(MaybeRelocatable::from(ep.offset));
        b.push(MaybeRelocatable::from(ep.builtins.len()));
        let builtins: Vec<MaybeRelocatable> = ep
            .builtins
            .iter()
            .map(|bi| MaybeRelocatable::from(Felt252::from_bytes_be_slice(bi.as_bytes())))
            .collect();
        let builtins_base = vm.add_memory_segment();
        vm.load_data(builtins_base, &builtins)?;
        b.push(builtins_base.into());
    }
    vm.insert_value(base, Felt252::from(entry_points.len()))?;
    let externals_base = vm.add_memory_segment();
    vm.load_data(externals_base, &b)?;
    vm.insert_value((base + 1)?, externals_base)?;

    Ok(())
}
