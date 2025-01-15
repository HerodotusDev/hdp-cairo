use crate::vars;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;
use types::proofs::starknet::{storage::Storage, Proofs};

pub const HINT_BATCH_STORAGES_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch_starknet.storages))";

pub fn hint_batch_storages_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(batch.storages.len()))
}

pub const HINT_SET_BATCH_STORAGES: &str = "storage_starknet = batch_starknet.storages[ids.idx]";

pub fn hint_set_batch_storages(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH_STARKNET)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let storage = batch.storages[idx].clone();

    exec_scopes.insert_value::<Storage>(vars::scopes::STORAGE_STARKNET, storage);

    Ok(())
}

pub const HINT_SET_STORAGE_ADDRESSES_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(storage_starknet.storage_addresses))";

pub fn hint_set_storage_addresses_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(storage.storage_addresses.len()))
}

pub const HINT_SET_CONTRACT_ADDRESS: &str = "memory[ap] = to_felt_or_relocatable(storage_starknet.contract_address)";

pub fn hint_set_contract_address(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(storage.storage_addresses.len()))
}

pub const HINT_SET_STORAGE_ADDRESSES: &str = "segments.write_arg(ids.storage_addresses, [int(x, 16) for x in storage_starknet.storage_addresses]))";

pub fn hint_set_storage_addresses(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    let address_ptr = get_ptr_from_var_name(vars::ids::STORAGE_ADDRESSES, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(
        address_ptr,
        &storage
            .storage_addresses
            .into_iter()
            .map(MaybeRelocatable::from)
            .collect::<Vec<MaybeRelocatable>>(),
    )?;

    Ok(())
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_CLASS_HASH: &str =
    "memory[ap] = to_felt_or_relocatable(storage_starknet.proof.contract_data.class_hash)";

pub fn hint_set_storage_starknet_proof_contract_data_class_hash(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(vm, storage.proof.contract_data.ok_or(HintError::WrongHintData)?.class_hash)
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_NONCE: &str =
    "memory[ap] = to_felt_or_relocatable(storage_starknet.proof.contract_data.nonce)";

pub fn hint_set_storage_starknet_proof_contract_data_nonce(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(vm, storage.proof.contract_data.ok_or(HintError::WrongHintData)?.nonce)
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_CONTRACT_STATE_HASH_VERSION: &str =
    "memory[ap] = to_felt_or_relocatable(storage_starknet.proof.contract_data.contract_state_hash_version)";

pub fn hint_set_storage_starknet_proof_contract_data_contract_state_hash_version(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(
        vm,
        storage.proof.contract_data.ok_or(HintError::WrongHintData)?.contract_state_hash_version,
    )
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_PROOF_LEN: &str =
    "memory[ap] = to_felt_or_relocatable(len(storage_starknet.proof.contract_proof))";

pub fn hint_set_storage_starknet_proof_contract_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(storage.proof.contract_proof.len()))
}

pub const HINT_SET_CONTRACT_NODES: &str = "segments.write_arg(ids.contract_nodes, storage_starknet.proof.contract_proof)";

pub fn hint_set_contract_nodes(
    _vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    // let contract_nodes_ptr = get_ptr_from_var_name(vars::ids::CONTRACT_NODES, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    // unimplemented!();

    // Ok(())

    todo!()
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CLASS_COMMITMENT: &str = "memory[ap] = to_felt_or_relocatable(storage_starknet.proof.class_commitment)";

pub fn hint_set_storage_starknet_proof_class_commitment(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    insert_value_into_ap(vm, storage.proof.class_commitment.ok_or(HintError::WrongHintData)?)
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_STORAGE_PROOFS_LEN: &str =
    "memory[ap] = to_felt_or_relocatable(len(storage_starknet.proof.contract_data.storage_proofs[ids.idx]))";

pub fn hint_set_storage_starknet_proof_contract_data_storage_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    insert_value_into_ap(vm, storage.proof.contract_data.ok_or(HintError::WrongHintData)?.storage_proofs[idx].len())
}

pub const HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_STORAGE_PROOF: &str =
    "segments.write_arg(ids.contract_state_nodes, storage_starknet.proof.contract_data.storage_proofs[ids.idx])";

pub fn hint_set_storage_starknet_proof_contract_data_storage_proof(
    _vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_STARKNET)?;

    // let contract_state_nodes_ptr = get_ptr_from_var_name(vars::ids::CONTRACT_STATE_NODES, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    // unimplemented!();

    // Ok(())

    todo!()
}
