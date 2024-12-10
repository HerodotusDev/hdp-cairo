use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name},
    },
    types::relocatable::MaybeRelocatable,
};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use starknet_types_core::felt::NonZeroFelt;
use std::collections::HashMap;

use crate::hints::vars;

pub const HINT_DIVMOD_RLP: &str = "ids.q, ids.r = divmod(memory[ids.rlp + ids.i], ids.devisor)";

pub fn hint_divmod_rlp(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let rlp = get_ptr_from_var_name(vars::ids::RLP, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let i: usize = get_integer_from_var_name(vars::ids::I, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let devisor = get_integer_from_var_name(vars::ids::DEVISOR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let (q, r) = vm.get_integer((rlp + i)?)?.div_rem(&NonZeroFelt::try_from(devisor).unwrap());

    insert_value_from_var_name(vars::ids::Q, MaybeRelocatable::Int(q), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    insert_value_from_var_name(vars::ids::R, MaybeRelocatable::Int(r), vm, &hint_data.ids_data, &hint_data.ap_tracking)
}

pub const HINT_DIVMOD_VALUE: &str = "ids.q, ids.r = divmod(memory[ids.value + ids.i], ids.devisor)";

pub fn hint_divmod_value(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value = get_ptr_from_var_name(vars::ids::VALUE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let i: usize = get_integer_from_var_name(vars::ids::I, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let devisor = get_integer_from_var_name(vars::ids::DEVISOR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let (q, r) = vm.get_integer((value + i)?)?.div_rem(&NonZeroFelt::try_from(devisor).unwrap());

    insert_value_from_var_name(vars::ids::Q, MaybeRelocatable::Int(q), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    insert_value_from_var_name(vars::ids::R, MaybeRelocatable::Int(r), vm, &hint_data.ids_data, &hint_data.ap_tracking)
}
