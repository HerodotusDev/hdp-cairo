use std::collections::HashMap;

use cairo_vm::{
    any_box,
    hint_processor::{
        builtin_hint_processor::{
            builtin_hint_processor_definition::HintProcessorData,
            hint_utils::{
                get_integer_from_var_name, get_ptr_from_var_name, get_relocatable_from_var_name, insert_value_from_var_name,
                insert_value_into_ap,
            },
        },
        hint_processor_utils::felt_to_usize,
    },
    types::{errors::math_errors::MathError, exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
};
use num_bigint::BigUint;
use num_traits::{One, ToPrimitive};
use types::{cairo::traits::CairoType, Felt252};

use crate::{
    patricia::{
        error::PatriciaHintError,
        tree::{build_update_tree, decode_node, patricia_guess_descents},
        types::{
            DecodeNodeCase, DecodedNode, DescentMap, DescentPath, DescentStart, Height, NodeEdge, NodePath, PatriciaSkipValidationRunner,
            Preimage, StorageLeaf, TreeUpdate, UpdateTree,
        },
    },
    vars,
};

pub const SET_SIBLINGS: &str = "memory[ids.siblings], ids.word = descend";

pub fn set_siblings(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let descend: DescentPath = exec_scopes.get(vars::scopes::DESCEND)?;

    let length = descend.0;
    let relative_path = descend.1;

    let siblings = get_ptr_from_var_name(vars::ids::SIBLINGS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.insert_value(siblings, Felt252::from(length.0))?;

    insert_value_from_var_name(
        vars::ids::WORD,
        Felt252::from(relative_path.0),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const IS_CASE_RIGHT: &str = "memory[ap] = int(case == 'right') ^ ids.bit";

pub fn is_case_right(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let case: DecodeNodeCase = exec_scopes.get(vars::scopes::CASE)?;
    let bit = get_integer_from_var_name(vars::ids::BIT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let case_felt = match case {
        DecodeNodeCase::Right => Felt252::ONE,
        _ => Felt252::ZERO,
    };

    // Felts do not support XOR, perform the computation on biguints.
    let value = bit.to_biguint() ^ case_felt.to_biguint();
    let value_felt = Felt252::from(&value);
    insert_value_into_ap(vm, value_felt)?;

    Ok(())
}

pub const SET_BIT: &str = "ids.bit = (ids.edge.path >> ids.new_length) & 1";

pub fn set_bit(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let edge_ptr = get_relocatable_from_var_name(vars::ids::EDGE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let edge_path = vm.get_integer((edge_ptr + NodeEdge::path_offset())?)?.into_owned();
    let new_length = {
        let new_length = get_integer_from_var_name(vars::ids::NEW_LENGTH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
        new_length.to_u64().ok_or(MathError::Felt252ToU64Conversion(Box::new(new_length)))?
    };

    let bit = (edge_path.to_biguint() >> new_length) & BigUint::one();
    let bit_felt = Felt252::from(&bit);
    insert_value_from_var_name(vars::ids::BIT, bit_felt, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    Ok(())
}

pub const SET_AP_TO_DESCEND: &str = r#"descend = descent_map.get((ids.height, ids.path))
memory[ap] = 0 if descend is None else 1"#;

pub fn set_ap_to_descend(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let descent_map: DescentMap = exec_scopes.get(vars::scopes::DESCENT_MAP)?;

    let height = get_integer_from_var_name(vars::ids::HEIGHT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let path = get_integer_from_var_name(vars::ids::PATH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let height = height.try_into()?;
    let path = NodePath(path.to_biguint());

    let descent_start = DescentStart(height, path);
    let ap = match descent_map.get(&descent_start) {
        None => Felt252::ZERO,
        Some(value) => {
            exec_scopes.insert_value(vars::scopes::DESCEND, value.clone());
            Felt252::ONE
        }
    };

    insert_value_into_ap(vm, ap)?;

    Ok(())
}

pub const ASSERT_CASE_IS_RIGHT: &str = "assert case == 'right'";

pub fn assert_case_is_right(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let case: DecodeNodeCase = exec_scopes.get(vars::scopes::CASE)?;
    if case != DecodeNodeCase::Right {
        return Err(PatriciaHintError::AssertCaseRightFailed(case).into());
    }
    Ok(())
}

pub const WRITE_CASE_NOT_LEFT_TO_AP: &str = "memory[ap] = int(case != 'left')";

pub fn write_case_not_left_to_ap(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let case: DecodeNodeCase = exec_scopes.get(vars::scopes::CASE)?;
    let value = Felt252::from(case != DecodeNodeCase::Left);
    insert_value_into_ap(vm, value)?;
    Ok(())
}

pub const SPLIT_DESCEND: &str = "ids.length, ids.word = descend";

pub fn split_descend(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let descend: DescentPath = exec_scopes.get(vars::scopes::DESCEND)?;

    let length = descend.0;
    let word = descend.1;

    insert_value_from_var_name(
        vars::ids::LENGTH,
        Felt252::from(length.0),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    insert_value_from_var_name(
        vars::ids::WORD,
        Felt252::from(word.0),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const HEIGHT_IS_ZERO_OR_LEN_NODE_PREIMAGE_IS_TWO: &str = "memory[ap] = 1 if ids.height == 0 or len(preimage[ids.node]) == 2 else 0";

pub fn height_is_zero_or_len_node_preimage_is_two(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let height = get_integer_from_var_name(vars::ids::HEIGHT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let node = get_integer_from_var_name(vars::ids::NODE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let ap = if height == Felt252::ZERO {
        Felt252::ONE
    } else {
        let preimage: Preimage = exec_scopes.get(vars::scopes::PREIMAGE)?;
        let preimage_value = preimage
            .get(node.as_ref())
            .ok_or(HintError::CustomHint("No preimage found for node".to_string().into_boxed_str()))?;
        Felt252::from(preimage_value.len() == 2)
    };

    insert_value_into_ap(vm, ap)?;

    Ok(())
}

pub const LOAD_EDGE: &str = r#"ids.edge = segments.add()
ids.edge.length, ids.edge.path, ids.edge.bottom = preimage[ids.node]
ids.hash_ptr.result = ids.node - ids.edge.length
if __patricia_skip_validation_runner is not None:
    # Skip validation of the preimage dict to speed up the VM. When this flag is set,
    # mistakes in the preimage dict will be discovered only in the prover.
    __patricia_skip_validation_runner.verified_addresses.add(
        ids.hash_ptr + ids.HashBuiltin.result)"#;

pub fn load_edge(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let new_segment_base = vm.add_memory_segment();
    insert_value_from_var_name(vars::ids::EDGE, new_segment_base, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let preimage: HashMap<Felt252, Vec<Felt252>> = exec_scopes.get(vars::scopes::PREIMAGE)?;
    let node = get_integer_from_var_name(vars::ids::NODE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let node_values = preimage.get(&node).ok_or(HintError::CustomHint(
        "preimage does not contain expected edge".to_string().into_boxed_str(),
    ))?;

    if node_values.len() != 3 {
        return Err(HintError::CustomHint(
            "preimage value does not appear to be a NodeEdge".to_string().into_boxed_str(),
        ));
    }
    let edge = NodeEdge {
        length: node_values[0],
        path: node_values[1],
        bottom: node_values[2],
    };
    edge.to_memory(vm, new_segment_base)?;

    // TODO: prevent underflow (original hint doesn't appear to care)?
    // compute `ids.hash_ptr.result = ids.node - ids.edge.length`
    let res = node - edge.length;

    // ids.hash_ptr refers to SpongeHashBuiltin (see cairo-lang's sponge_as_hash.cairo)
    let hash_ptr = get_ptr_from_var_name(vars::ids::HASH_PTR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let hash_result_ptr = (hash_ptr + 2)?;
    vm.insert_value(hash_result_ptr, res)?;

    skip_verification_if_configured(exec_scopes, hash_result_ptr)?;

    Ok(())
}

/// Inserts a hash result address in `__patricia_skip_validation_runner` if it exists.
///
/// This skips validation of the preimage dict to speed up the VM. When this flag is set,
/// mistakes in the preimage dict will be discovered only in the prover.
pub fn skip_verification_if_configured(exec_scopes: &mut ExecutionScopes, address: Relocatable) -> Result<(), HintError> {
    let patricia_skip_validation_runner: &mut Option<PatriciaSkipValidationRunner> =
        exec_scopes.get_mut_ref(vars::scopes::PATRICIA_SKIP_VALIDATION_RUNNER)?;
    if let Some(skipped) = patricia_skip_validation_runner {
        skipped.verified_addresses.insert(address);
    }

    Ok(())
}

pub const PREPARE_PREIMAGE_VALIDATION_NON_DETERMINISTIC_HASHES: &str = r#"from starkware.python.merkle_tree import decode_node
left_child, right_child, case = decode_node(node)

left_hash, right_hash = preimage[ids.node]

# Fill non deterministic hashes.
hash_ptr = ids.current_hash.address_
memory[hash_ptr + ids.HashBuiltin.x] = left_hash
memory[hash_ptr + ids.HashBuiltin.y] = right_hash

if __patricia_skip_validation_runner:
    # Skip validation of the preimage dict to speed up the VM. When this flag is set,
    # mistakes in the preimage dict will be discovered only in the prover.
    __patricia_skip_validation_runner.verified_addresses.add(
        hash_ptr + ids.HashBuiltin.result)

memory[ap] = int(case != 'both')"#;

pub fn prepare_preimage_validation_non_deterministic_hashes(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let (x_offset, y_offset, result_offset) = (0usize, 1usize, 2usize);

    let node: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::NODE)?;
    let node = node.ok_or(HintError::AssertionFailed("'node' should not be None".to_string().into_boxed_str()))?;

    let preimage: Preimage = exec_scopes.get(vars::scopes::PREIMAGE)?;

    let ids_node = get_integer_from_var_name(vars::ids::NODE, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let DecodedNode {
        left_child,
        right_child,
        case,
    } = decode_node(&node)?;

    exec_scopes.insert_value(vars::scopes::LEFT_CHILD, left_child.clone());
    exec_scopes.insert_value(vars::scopes::RIGHT_CHILD, right_child.clone());
    exec_scopes.insert_value(vars::scopes::CASE, case.clone());

    let node_preimage = preimage
        .get(&ids_node)
        .ok_or(HintError::CustomHint("Node preimage not found".to_string().into_boxed_str()))?;
    let left_hash = node_preimage[0];
    let right_hash = node_preimage[1];

    // Fill non deterministic hashes.
    let hash_ptr = get_ptr_from_var_name(vars::ids::CURRENT_HASH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    // memory[hash_ptr + ids.HashBuiltin.x] = left_hash
    vm.insert_value((hash_ptr + x_offset)?, left_hash)?;
    // memory[hash_ptr + ids.HashBuiltin.y] = right_hash
    vm.insert_value((hash_ptr + y_offset)?, right_hash)?;

    let hash_result_address = (hash_ptr + result_offset)?;
    skip_verification_if_configured(exec_scopes, hash_result_address)?;

    // memory[ap] = int(case != 'both')"#
    let ap = match case {
        DecodeNodeCase::Both => Felt252::ZERO,
        _ => Felt252::ONE,
    };
    insert_value_into_ap(vm, ap)?;

    Ok(())
}

pub const ENTER_SCOPE_NODE: &str = "vm_enter_scope(dict(node=node, **common_args))";

pub fn enter_scope_node_hint(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let node: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::NODE)?;
    enter_node_scope(node, exec_scopes)
}

pub const ENTER_SCOPE_NEXT_NODE_BIT_0: &str = r#"new_node = left_child if ids.bit == 0 else right_child
vm_enter_scope(dict(node=new_node, **common_args))"#;

pub fn enter_scope_next_node_bit_0(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    enter_scope_next_node(Felt252::ZERO, vm, exec_scopes, hint_data)
}

pub const ENTER_SCOPE_NEXT_NODE_BIT_1: &str = r#"new_node = left_child if ids.bit == 1 else right_child
vm_enter_scope(dict(node=new_node, **common_args))"#;

pub fn enter_scope_next_node_bit_1(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    enter_scope_next_node(Felt252::ONE, vm, exec_scopes, hint_data)
}

pub const ENTER_SCOPE_LEFT_CHILD: &str = "vm_enter_scope(dict(node=left_child, **common_args))";

pub fn enter_scope_left_child(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left_child: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::LEFT_CHILD)?;
    enter_node_scope(left_child, exec_scopes)
}

pub const ENTER_SCOPE_RIGHT_CHILD: &str = "vm_enter_scope(dict(node=right_child, **common_args))";

pub fn enter_scope_right_child(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let right_child: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::RIGHT_CHILD)?;
    enter_node_scope(right_child, exec_scopes)
}

pub fn enter_node_scope(node: UpdateTree<StorageLeaf>, exec_scopes: &mut ExecutionScopes) -> Result<(), HintError> {
    // vm_enter_scope(dict(node=new_node, **common_args))"#
    // In this implementation we assume that `common_args` is unpacked, having a
    // `HashMap<String, Box<dyn Any>>` as scope variable is unpractical.
    // `common_args` contains the 3 variables below and is never modified.
    let new_scope = {
        let preimage: Preimage = exec_scopes.get(vars::scopes::PREIMAGE)?;
        let descent_map: DescentMap = exec_scopes.get(vars::scopes::DESCENT_MAP)?;
        let patricia_skip_validation_runner: Option<PatriciaSkipValidationRunner> =
            exec_scopes.get(vars::scopes::PATRICIA_SKIP_VALIDATION_RUNNER)?;

        HashMap::from([
            (vars::scopes::NODE.to_string(), any_box!(node)),
            (vars::scopes::PREIMAGE.to_string(), any_box!(preimage)),
            (vars::scopes::DESCENT_MAP.to_string(), any_box!(descent_map)),
            (
                vars::scopes::PATRICIA_SKIP_VALIDATION_RUNNER.to_string(),
                any_box!(patricia_skip_validation_runner),
            ),
        ])
    };
    exec_scopes.enter_scope(new_scope);

    Ok(())
}

fn enter_scope_next_node(
    bit_value: Felt252,
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
) -> Result<(), HintError> {
    let left_child: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::LEFT_CHILD)?;
    let right_child: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::RIGHT_CHILD)?;

    let bit = get_integer_from_var_name(vars::ids::BIT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let next_node = if bit.as_ref() == &bit_value { left_child } else { right_child };

    enter_node_scope(next_node, exec_scopes)?;

    Ok(())
}

pub const ENTER_SCOPE_NEW_NODE: &str = r#"ids.child_bit = 0 if case == 'left' else 1
new_node = left_child if case == 'left' else right_child
vm_enter_scope(dict(node=new_node, **common_args))"#;

pub fn enter_scope_new_node(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let left_child: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::LEFT_CHILD)?;
    let right_child: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::RIGHT_CHILD)?;
    let case: DecodeNodeCase = exec_scopes.get(vars::scopes::CASE)?;

    let (child_bit, new_node) = match case {
        DecodeNodeCase::Left => (Felt252::ZERO, left_child),
        _ => (Felt252::ONE, right_child),
    };

    insert_value_from_var_name(vars::ids::CHILD_BIT, child_bit, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    enter_node_scope(new_node, exec_scopes)?;

    Ok(())
}

pub const DECODE_NODE: &str = r#"from starkware.python.merkle_tree import decode_node
left_child, right_child, case = decode_node(node)
memory[ap] = int(case != 'both')"#;

pub const DECODE_NODE_2: &str = r#"from starkware.python.merkle_tree import decode_node
left_child, right_child, case = decode_node(node)
memory[ap] = 1 if case != 'both' else 0"#;

pub fn decode_node_hint(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let node: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::NODE)?;
    let node = node.ok_or(HintError::AssertionFailed("'node' should not be None".to_string().into_boxed_str()))?;
    let DecodedNode {
        left_child,
        right_child,
        case,
    } = decode_node(&node)?;
    exec_scopes.insert_value(vars::scopes::LEFT_CHILD, left_child.clone());
    exec_scopes.insert_value(vars::scopes::RIGHT_CHILD, right_child.clone());
    exec_scopes.insert_value(vars::scopes::CASE, case.clone());

    // memory[ap] = 1 if case != 'both' else 0"#
    let ap = match case {
        DecodeNodeCase::Both => Felt252::ZERO,
        _ => Felt252::ONE,
    };
    insert_value_into_ap(vm, ap)?;

    Ok(())
}

pub const ENTER_SCOPE_DESCEND_EDGE: &str = r#"new_node = node
for i in range(ids.length - 1, -1, -1):
    new_node = new_node[(ids.word >> i) & 1]
vm_enter_scope(dict(node=new_node, **common_args))"#;

pub fn enter_scope_descend_edge(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let mut new_node: UpdateTree<StorageLeaf> = exec_scopes.get(vars::scopes::NODE)?;
    let length = {
        let length = get_integer_from_var_name(vars::ids::LENGTH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
        length.to_u64().ok_or(MathError::Felt252ToU64Conversion(Box::new(length)))?
    };
    let word = get_integer_from_var_name(vars::ids::WORD, vm, &hint_data.ids_data, &hint_data.ap_tracking)?.to_biguint();

    for i in (0..length).rev() {
        match new_node {
            None => {
                return Err(HintError::CustomHint("Expected a node".to_string().into_boxed_str()));
            }
            Some(TreeUpdate::Leaf(_)) => {
                return Err(HintError::CustomHint("Did not expect a leaf node".to_string().into_boxed_str()));
            }
            Some(TreeUpdate::Tuple(left_child, right_child)) => {
                // new_node = new_node[(ids.word >> i) & 1]
                let one_biguint = BigUint::from(1u64);
                let descend_right = ((&word >> i) & &one_biguint) == one_biguint;
                if descend_right {
                    new_node = *right_child;
                } else {
                    new_node = *left_child;
                }
            }
        }
    }

    enter_node_scope(new_node, exec_scopes)
}

pub const BUILD_DESCENT_MAP: &str = r#"from starkware.cairo.common.patricia_utils import canonic, patricia_guess_descents
from starkware.python.merkle_tree import build_update_tree

# Build modifications list.
modifications = []
DictAccess_key = ids.DictAccess.key
DictAccess_new_value = ids.DictAccess.new_value
DictAccess_SIZE = ids.DictAccess.SIZE
for i in range(ids.n_updates):
    curr_update_ptr = ids.update_ptr.address_ + i * DictAccess_SIZE
    modifications.append((
        memory[curr_update_ptr + DictAccess_key],
        memory[curr_update_ptr + DictAccess_new_value]))

node = build_update_tree(ids.height, modifications)
descent_map = patricia_guess_descents(
    ids.height, node, preimage, ids.prev_root, ids.new_root)
del modifications
__patricia_skip_validation_runner = globals().get(
    '__patricia_skip_validation_runner')

common_args = dict(
    preimage=preimage, descent_map=descent_map,
    __patricia_skip_validation_runner=__patricia_skip_validation_runner)
common_args['common_args'] = common_args"#;

pub fn build_descent_map(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // Build modifications list.
    let n_updates = get_integer_from_var_name(vars::ids::N_UPDATES, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let n_updates = felt_to_usize(&n_updates)?;
    let update_ptr_address = get_ptr_from_var_name(vars::ids::UPDATE_PTR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let modifications = (0..n_updates)
        .map(|i| {
            let curr_update_ptr = (update_ptr_address + i * 3)?;
            let key = vm.get_integer(curr_update_ptr)?.into_owned().to_biguint();
            let value = vm.get_integer((curr_update_ptr + 2)?)?.into_owned();
            Ok((key, StorageLeaf::new(value)))
        })
        .collect::<Result<Vec<_>, HintError>>()?;

    // Build the descent map.
    let height: Height = get_integer_from_var_name(vars::ids::HEIGHT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?.try_into()?;
    let prev_root = get_integer_from_var_name(vars::ids::PREV_ROOT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?.to_biguint();
    let new_root = get_integer_from_var_name(vars::ids::NEW_ROOT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?.to_biguint();

    let preimage: &Preimage = exec_scopes.get_ref(vars::scopes::PREIMAGE)?;

    let node: UpdateTree<StorageLeaf> = build_update_tree(height, modifications);
    let descent_map = patricia_guess_descents::<StorageLeaf>(height, node.clone(), preimage, prev_root, new_root)?;

    exec_scopes.insert_value(vars::scopes::NODE, node.clone());
    // Notes:
    // 1. We do not build `common_args` as it seems to be a Python trick to enter new scopes with a dict destructuring one-liner as the dict
    //    references itself. Neat trick that does not translate too well in Rust. We just make sure that `descent_map`,
    //    `__patricia_skip_validation_runner` and `preimage` are in the scope.
    // 2. The Rust VM has no `globals()`, `__patricia_skip_validation_runner` should already be in `exec_scopes.data[0]`.
    // 3. `preimage` is guaranteed to be present as we fetch it earlier. Conclusion: we only need to insert
    //    `__patricia_skip_validation_runner` and `descent_map`.
    exec_scopes.insert_value(vars::scopes::DESCENT_MAP, descent_map);

    let patricia_skip_validation_runner_from_root: Option<PatriciaSkipValidationRunner> =
        match get_variable_from_root_exec_scope::<Option<PatriciaSkipValidationRunner>>(
            exec_scopes,
            vars::scopes::PATRICIA_SKIP_VALIDATION_RUNNER,
        ) {
            Ok(val) => val, // val is Option<PatriciaSkipValidationRunner>
            Err(HintError::VariableNotInScopeError(_)) => {
                // If the variable key is not in the root scope, default to None.
                None
            }
            Err(e) => return Err(e), // Propagate other errors
        };
    exec_scopes.insert_value(
        vars::scopes::PATRICIA_SKIP_VALIDATION_RUNNER,
        patricia_skip_validation_runner_from_root,
    );

    Ok(())
}

/// Retrieve a variable from the root execution scope.
///
/// Some global variables are stored in the root execution scope on startup. We sometimes
/// need access to these variables from a hint where we are already in a nested scope.
/// This function retrieves the variable from the root scope regardless of the current scope.
pub(crate) fn get_variable_from_root_exec_scope<T>(exec_scopes: &ExecutionScopes, name: &str) -> Result<T, HintError>
where
    T: Clone + 'static,
{
    exec_scopes.data[0]
        .get(name)
        .and_then(|var| var.downcast_ref::<T>().cloned())
        .ok_or(HintError::VariableNotInScopeError(name.to_string().into_boxed_str()))
}
