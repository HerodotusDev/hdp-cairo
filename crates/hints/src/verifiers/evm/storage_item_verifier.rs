use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{
            get_address_from_var_name, get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name, insert_value_into_ap,
        },
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use types::proofs::{
    evm::{storage::Storage, Proofs},
    mpt::MPTProof,
};

use crate::{
    utils::{count_leading_zero_nibbles_from_hex, split_128},
    vars,
};

pub const HINT_BATCH_STORAGES_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch_evm.storages))";

pub fn hint_batch_storages_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH_EVM)?;

    insert_value_into_ap(vm, Felt252::from(batch.storages.len()))
}

pub const HINT_SET_BATCH_STORAGES: &str =
    "storage_evm = batch_evm.storages[ids.idx]\nsegments.write_arg(ids.address, [int(x, 16) for x in storage_evm.address]))";

pub fn hint_set_batch_storages(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH_EVM)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let storage = batch.storages[idx].clone();
    let address_le_chunks: Vec<MaybeRelocatable> = storage
        .address
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

    exec_scopes.insert_value::<Storage>(vars::scopes::STORAGE_EVM, storage);

    let address_ptr = get_ptr_from_var_name(vars::ids::ADDRESS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(address_ptr, &address_le_chunks)?;

    Ok(())
}

pub const HINT_SET_STORAGE_SLOT: &str = "segments.write_arg(ids.slot, [int(x, 16) for x in storage_evm.slot]))";

pub fn hint_set_storage_slot(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_EVM)?;
    let slot_le_chunks: Vec<MaybeRelocatable> = storage
        .slot
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

    let slot_ptr = get_ptr_from_var_name(vars::ids::SLOT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(slot_ptr, &slot_le_chunks)?;

    Ok(())
}

pub const HINT_SET_STORAGE_KEY: &str = "(ids.key.low, ids.key.high) = split_128(int(storage_evm.storage_key, 16))";

pub fn hint_set_storage_key(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_EVM)?;

    let (key_low, key_high) = split_128(&BigUint::from_bytes_be(storage.storage_key.as_slice()));

    let key_ptr = get_address_from_var_name(vars::ids::KEY, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.insert_value(
        (key_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 0)?,
        Felt252::from(key_low),
    )?;
    vm.insert_value(
        (key_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 1)?,
        Felt252::from(key_high),
    )?;

    Ok(())
}

pub const HINT_SET_STORAGE_KEY_LEADING_ZEROS: &str =
    "ids.key_leading_zeros = len(storage_evm.storage_key.lstrip(\"0x\")) - len(storage_evm.storage_key.lstrip(\"0x\").lstrip(\"0\"))";

pub fn hint_set_storage_key_leading_zeros(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_EVM)?;
    let key_leading_zeros = count_leading_zero_nibbles_from_hex(&storage.storage_key.to_string());

    insert_value_from_var_name(
        vars::ids::KEY_LEADING_ZEROS,
        MaybeRelocatable::Int(Felt252::from(key_leading_zeros)),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const HINT_SET_STORAGE_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(storage_evm.proofs))";

pub fn hint_set_storage_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_EVM)?;

    insert_value_into_ap(vm, Felt252::from(storage.proofs.len()))
}

pub const HINT_SET_STORAGE_PROOF_AT: &str = "proof = storage_evm.proofs[ids.idx]";

pub fn hint_set_storage_proof_at(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE_EVM)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let proof = storage.proofs[idx].clone();

    exec_scopes.insert_value::<MPTProof>(vars::scopes::PROOF, proof);

    Ok(())
}

pub const HINT_SET_PROOF_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(proof.proof))";

pub fn hint_set_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;

    insert_value_into_ap(vm, Felt252::from(proof.proof.len()))
}

pub const HINT_SET_PROOF_BLOCK_NUMBER: &str = "memory[ap] = to_felt_or_relocatable(proof.block_number)";

pub fn hint_set_proof_block_number(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;

    insert_value_into_ap(vm, Felt252::from(proof.block_number))
}
