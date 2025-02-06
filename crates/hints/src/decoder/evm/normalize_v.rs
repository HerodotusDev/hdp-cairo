use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_relocatable_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

const FELT_35: Felt252 = Felt252::from_hex_unchecked("0x23");
const FELT_36: Felt252 = Felt252::from_hex_unchecked("0x24");
const FELT_55: Felt252 = Felt252::from_hex_unchecked("0x37");

pub const HINT_IS_EIP155: &str = "ids.is_eip155 = 1 if ids.chain_info.id * 2 + 35 <= ids.v.low <= ids.chain_info.id * 2 + 36 else 0";

pub fn hint_is_eip155(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let chain_info = get_relocatable_from_var_name("chain_info", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let id = *vm.get_integer((chain_info + 0)?)?;

    let v_ptr = get_relocatable_from_var_name("v", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let v = vm
        .get_continuous_range(v_ptr, 2)?
        .into_iter()
        .map(|v| v.get_int().unwrap())
        .collect::<Vec<Felt252>>();

    let insert = if id * Felt252::TWO + FELT_35 <= v[0] && v[0] <= id * Felt252::TWO + FELT_36 {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };

    insert_value_from_var_name(
        "is_eip155",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_IS_SHORT: &str = "ids.is_short = 1 if ids.tx_payload_bytes_len <= 55 else 0";

pub fn hint_is_short(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let tx_payload_bytes_len = get_integer_from_var_name("tx_payload_bytes_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = if tx_payload_bytes_len <= FELT_55 {
        Felt252::ONE
    } else {
        Felt252::ZERO
    };

    insert_value_from_var_name(
        "is_short",
        MaybeRelocatable::Int(insert),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
