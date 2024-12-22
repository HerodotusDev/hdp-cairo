use crate::vars;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub const PROGRAM_HASH: &str = "print(\"program_hash\", hex(ids.program_hash))";

pub fn program_hash(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let program_hash = get_integer_from_var_name(vars::ids::PROGRAM_HASH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    println!("program_hash: {}", program_hash);

    Ok(())
}

pub const PRINT2: &str = "print2";

pub fn print2(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    println!("i: {}", get_integer_from_var_name("i", vm, &hint_data.ids_data, &hint_data.ap_tracking)?);
    println!("q: {}", get_integer_from_var_name("q", vm, &hint_data.ids_data, &hint_data.ap_tracking)?);
    println!("r: {}", get_integer_from_var_name("r", vm, &hint_data.ids_data, &hint_data.ap_tracking)?);
    println!(
        "devisor: {}",
        get_integer_from_var_name("devisor", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
    );

    let i: usize = get_integer_from_var_name("i", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    println!("i: {}", i);
    println!(
        "devisor: {}",
        get_integer_from_var_name("devisor", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
    );
    let ptr = get_ptr_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    println!("value[i] {}", vm.get_integer((ptr + i)?)?);
    println!(
        "{}",
        get_integer_from_var_name("q", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
            * get_integer_from_var_name("devisor", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
            + get_integer_from_var_name("r", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
    );

    Ok(())
}

pub const PRINT1: &str = "print1";

pub fn print1(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let i: usize = get_integer_from_var_name("i", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    println!("i: {}", i);
    println!(
        "devisor: {}",
        get_integer_from_var_name("devisor", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
    );
    let ptr = get_ptr_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    println!("value[i] {}", vm.get_integer((ptr + i)?)?);

    let ptr = get_ptr_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    println!("ptr {}", ptr);

    Ok(())
}
