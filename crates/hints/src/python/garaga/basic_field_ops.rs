use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{
            get_address_from_var_name, get_integer_from_var_name, get_ptr_from_var_name, get_relocatable_from_var_name,
            insert_value_into_ap,
        },
    },
    types::{
        exec_scope::ExecutionScopes,
        relocatable::{MaybeRelocatable, Relocatable},
    },
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_traits::ToPrimitive;
use types::cairo::traits::CairoType;

use super::types::UInt384;

pub const HINT_UINT384_IS_LE: &str = r#"from garaga.hints.io import bigint_pack
a = bigint_pack(ids.a, 4, 2**96)
b = bigint_pack(ids.b, 4, 2**96)
ids.flag = int(a <= b)"#;

pub fn hint_uint384_is_le(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let a_ptr = get_relocatable_from_var_name("a", vm, &hint_data.ids_data, &hint_data.ap_tracking).unwrap();
    let b_ptr = get_relocatable_from_var_name("b", vm, &hint_data.ids_data, &hint_data.ap_tracking).unwrap();

    let a = UInt384::from_memory(vm, a_ptr).unwrap();
    let b = UInt384::from_memory(vm, b_ptr).unwrap();

    let flag = a <= b;

    let flag_ptr = get_address_from_var_name("flag", vm, &hint_data.ids_data, &hint_data.ap_tracking).unwrap();

    match flag_ptr {
        MaybeRelocatable::RelocatableValue(flag_ptr) => {
            vm.insert_value(flag_ptr, Felt252::from(flag)).unwrap();
        }
        _ => (),
    }

    Ok(())
}

pub const HINT_ADD_MOD_CIRCUIT: &str = r#"from starkware.cairo.lang.builtins.modulo.mod_builtin_runner import ModBuiltinRunner
assert builtin_runners["add_mod_builtin"].instance_def.batch_size == 1

ModBuiltinRunner.fill_memory(
    memory=memory,
    add_mod=(ids.add_mod_ptr.address_, builtin_runners["add_mod_builtin"], 1),
    mul_mod=None,
)"#;

pub fn hint_add_mod_circuit(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let add_mod_ptr = get_ptr_from_var_name("add_mod_ptr", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.mod_builtin_fill_memory(Some((add_mod_ptr, 1)), None, Some(1))
        .map_err(HintError::Internal)
}
