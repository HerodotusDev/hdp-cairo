use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_ptr_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use pathfinder_common::hash::keccak_hash;

use crate::vars;

pub const HINT_KECCAK160_BINARY_NODE: &str = "memory[ap] = to_felt_or_relocatable(keccak160(ids.node.left, ids.node.right))";

pub fn hint_keccak160_binary_node(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let node_ptr = get_ptr_from_var_name(vars::ids::NODE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let node_left = vm.get_integer((node_ptr + 1)?)?.into_owned();
    let node_right = vm.get_integer((node_ptr + 2)?)?.into_owned();
    insert_value_into_ap(
        vm,
        Felt252::from_bytes_be(
            &keccak_hash(
                pathfinder_crypto::Felt::from_be_bytes(node_left.to_bytes_be()).unwrap(),
                pathfinder_crypto::Felt::from_be_bytes(node_right.to_bytes_be()).unwrap(),
            )
            .to_be_bytes(),
        ),
    )
}

pub const HINT_KECCAK160_EDGE_NODE: &str = "memory[ap] = to_felt_or_relocatable(keccak160(ids.node.child, ids.node.value))";

pub fn hint_keccak160_edge_node(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let node_ptr = get_ptr_from_var_name(vars::ids::NODE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let node_child = vm.get_integer((node_ptr + 1)?)?.into_owned();
    let node_value = vm.get_integer((node_ptr + 2)?)?.into_owned();
    insert_value_into_ap(
        vm,
        Felt252::from_bytes_be(
            &keccak_hash(
                pathfinder_crypto::Felt::from_be_bytes(node_child.to_bytes_be()).unwrap(),
                pathfinder_crypto::Felt::from_be_bytes(node_value.to_bytes_be()).unwrap(),
            )
            .to_be_bytes(),
        ),
    )
}
