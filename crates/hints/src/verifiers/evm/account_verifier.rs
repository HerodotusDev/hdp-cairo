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
use types::proofs::{account::Account, mpt::MPTProof, Proofs};

pub const HINT_BATCH_ACCOUNTS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.accounts))";

pub fn hint_batch_accounts_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;

    insert_value_into_ap(vm, Felt252::from(batch.accounts.len()))
}

pub const HINT_GET_ACCOUNT_ADDRESS: &str =
    "account = batch.accounts[ids.idx]\nsegments.write_arg(ids.address, [int(x, 16) for x in account.address]))";

pub fn hint_get_account_address(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let account = batch.accounts[idx].clone();
    let address_le_chunks: Vec<MaybeRelocatable> = account
        .address
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

    exec_scopes.insert_value::<Account>(vars::scopes::ACCOUNT, account);

    let address_ptr = get_ptr_from_var_name(vars::ids::ADDRESS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.write_arg(address_ptr, &address_le_chunks)?;

    Ok(())
}

pub const HINT_ACCOUNT_KEY: &str = "from tools.py.utils import split_128\n(ids.key.low, ids.key.high) = split_128(int(account.account_key, 16))";

pub fn hint_account_key(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let account = exec_scopes.get::<Account>(vars::scopes::ACCOUNT)?;

    let (key_low, key_high) = split_128(&BigUint::from_bytes_be(account.account_key.as_slice()));

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

pub const HINT_ACCOUNT_KEY_LEADING_ZEROS: &str =
    "ids.key_leading_zeros = len(account.account_key.lstrip(\"0x\")) - len(account.account_key.lstrip(\"0x\").lstrip(\"0\"))";

pub fn hint_account_key_leading_zeros(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let account = exec_scopes.get::<Account>(vars::scopes::ACCOUNT)?;
    let key_leading_zeros = count_leading_zero_nibbles_from_hex(&account.account_key.to_string());

    insert_value_from_var_name(
        vars::ids::KEY_LEADING_ZEROS,
        MaybeRelocatable::Int(Felt252::from(key_leading_zeros)),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_ACCOUNT_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(account.proofs))";

pub fn hint_account_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let account = exec_scopes.get::<Account>(vars::scopes::ACCOUNT)?;

    insert_value_into_ap(vm, Felt252::from(account.proofs.len()))
}

pub const HINT_ACCOUNT_PROOF_AT: &str = "proof = account.proofs[ids.idx]";

pub fn hint_account_proof_at(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let account = exec_scopes.get::<Account>(vars::scopes::ACCOUNT)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    exec_scopes.insert_value::<MPTProof>(vars::scopes::PROOF, account.proofs[idx].clone());

    Ok(())
}

pub const HINT_ACCOUNT_PROOF_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(proof.proof))";

pub fn hint_account_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;

    insert_value_into_ap(vm, Felt252::from(proof.proof.len()))
}

pub const HINT_ACCOUNT_PROOF_BLOCK_NUMBER: &str = "memory[ap] = to_felt_or_relocatable(proof.block_number)";

pub fn hint_account_proof_block_number(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;

    insert_value_into_ap(vm, Felt252::from(proof.block_number))
}

pub const HINT_ACCOUNT_PROOF_BYTES_LEN: &str = "segments.write_arg(ids.proof_bytes_len, proof.proof_bytes_len)";

pub fn hint_account_proof_bytes_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;

    insert_value_from_var_name(
        vars::ids::PROOF_BYTES_LEN,
        MaybeRelocatable::Int(Felt252::from(proof.proof.len())),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_GET_MPT_PROOF: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in proof.proof])";

pub fn hint_get_mpt_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proof = exec_scopes.get::<MPTProof>(vars::scopes::PROOF)?;
    let mpt_proof_ptr = get_ptr_from_var_name(vars::ids::MPT_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let proof_le_chunks: Vec<Vec<MaybeRelocatable>> = proof
        .proof
        .into_iter()
        .map(|p| {
            p.chunks(8)
                .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
                .collect()
        })
        .collect();

    vm.write_arg(mpt_proof_ptr, &proof_le_chunks)?;

    Ok(())
}
