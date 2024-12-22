use crate::{
    utils::{count_leading_zero_nibbles_from_hex, split_128},
    vars,
};
use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_address_from_var_name, get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use std::collections::HashMap;
use types::proofs::{mpt::MPTProof, storage::Storage, Proofs};

pub const HINT_BATCH_STORAGES_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.storages))";

pub fn hint_batch_storages_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;

    insert_value_into_ap(vm, Felt252::from(batch.storages.len()))
}

pub const HINT_SET_BATCH_STORAGES: &str =
    "storage = batch.storages[ids.idx]\nsegments.write_arg(ids.address, [int(x, 16) for x in storage.address]))";

pub fn hint_set_batch_storages(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let storage = batch.storages[idx].clone();

    exec_scopes.insert_value::<Storage>(vars::scopes::STORAGE, storage);

    Ok(())
}

pub const HINT_SET_STORAGE_SLOT: &str = "segments.write_arg(ids.slot, [int(x, 16) for x in storage.slot]))";

pub fn hint_set_storage_slot(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE)?;
    let slot_le_chunks: Vec<MaybeRelocatable> = storage
        .slot
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

    let slot_ptr = get_ptr_from_var_name(vars::ids::SLOT, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.write_arg(slot_ptr, &slot_le_chunks)?;

    Ok(())
}

pub const HINT_SET_STORAGE_KEY: &str = "from tools.py.utils import split_128\n(ids.key.low, ids.key.high) = split_128(int(storage.storage_key, 16))";

pub fn hint_set_storage_key(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE)?;

    let (key_low, key_high) = split_128(&BigUint::from_bytes_be(storage.storage_key.as_slice()));
    
    let key_ptr = get_address_from_var_name(vars::ids::KEY, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.insert_value(
        (key_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 0)?,
        Felt252::try_from(key_low).map_err(|_| HintError::WrongHintData)?,
    )?;
    vm.insert_value(
        (key_ptr.get_relocatable().ok_or(HintError::WrongHintData)? + 1)?,
        Felt252::try_from(key_high).map_err(|_| HintError::WrongHintData)?,
    )?;

    Ok(())
}

pub const HINT_SET_STORAGE_KEY_LEADING_ZEROS: &str =
    "ids.key_leading_zeros = len(storage.storage_key.lstrip(\"0x\")) - len(storage.storage_key.lstrip(\"0x\").lstrip(\"0\"))";

pub fn hint_set_storage_key_leading_zeros(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE)?;
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

pub const HINT_SET_STORAGE_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(storage.proofs))";

pub fn hint_set_storage_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE)?;

    insert_value_into_ap(vm, Felt252::from(storage.proofs.len()))
}

pub const HINT_SET_STORAGE_PROOF_AT: &str = "proof = storage.proofs[ids.idx]";

pub fn hint_set_storage_proof_at(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let storage = exec_scopes.get::<Storage>(vars::scopes::STORAGE)?;
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

pub const HINT_SET_PROOF_BYTES_LEN: &str = "segments.write_arg(ids.proof_bytes_len, proof.proof_bytes_len)";

pub fn hint_set_proof_bytes_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;
    let proof_bytes_len_ptr = get_ptr_from_var_name(vars::ids::PROOF_BYTES_LEN, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.insert_value(proof_bytes_len_ptr, Felt252::from(proof.proof.len()))?;

    Ok(())
}

pub const HINT_SET_MPT_PROOF: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in proof.proof])";

pub fn hint_set_mpt_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;
    let mpt_proof_ptr = get_ptr_from_var_name(vars::ids::MPT_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let proof_le_chunks: Vec<MaybeRelocatable> = proof
        .proof
        .into_iter()
        .map(|p| {
            p.chunks(8)
                .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
                .collect()
        })
        .flat_map(|f: Vec<MaybeRelocatable>| f).collect();

    vm.load_data(mpt_proof_ptr, &proof_le_chunks)?;

    Ok(())
}
