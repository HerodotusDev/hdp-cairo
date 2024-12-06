use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{
            get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name,
        },
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use num_traits::Num;
use std::collections::HashMap;

use crate::hints::{
    lib::utils::{
        count_leading_zero_nibbles_from_hex, hex_to_int_array, nested_hex_to_int_array, split_128,
    },
    vars,
};

pub const HINT_N_ACCOUNTS: &str = "ids.n_accounts = len(batch[\"accounts\"])";

pub fn hint_n_accounts(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // TODO: Retrieve `batch["accounts"]` when supported.
    let n_accounts = Felt252::from(0);

    insert_value_from_var_name(
        vars::ids::N_ACCOUNTS,
        MaybeRelocatable::Int(n_accounts),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_N_PROOFS: &str = "ids.n_proofs = len(account[\"proofs\"])";

pub fn hint_n_proofs(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // TODO: Retrieve `account["proofs"]` when supported.
    let n_proofs = Felt252::from(0);

    insert_value_from_var_name(
        vars::ids::N_PROOFS,
        MaybeRelocatable::Int(n_proofs),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_ACCOUNT_KEY: &str = "from tools.py.utils import split_128, count_leading_zero_nibbles_from_hex, hex_to_int_array, nested_hex_to_int_array account = batch[\"accounts\"][ids.index] ids.key_leading_zeros = count_leading_zero_nibbles_from_hex(account[\"account_key\"]) segments.write_arg(ids.address, hex_to_int_array(account[\"address\"])) (key_low, key_high) = split_128(int(account[\"account_key\"], \"16\")) ids.key.low = key_low ids.key.high = key_high";

pub fn hint_account_key(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let _index = get_integer_from_var_name(
        vars::ids::INDEX,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    // TODO: Retrieve account_key from`batch["accounts"][index]` when supported.
    let account_key = "";
    let _key_leading_zeros = count_leading_zero_nibbles_from_hex(account_key);

    let address_ptr = get_ptr_from_var_name(
        vars::ids::ADDRESS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    // TODO: Retrieve address from `batch["accounts"][index]["address"]` when supported.
    let address_int_array = hex_to_int_array(&[]);
    vm.write_arg(address_ptr, &address_int_array)?;

    let (key_low, key_high) = split_128(&BigUint::from_str_radix(account_key, 16).unwrap());
    insert_value_from_var_name(
        vars::ids::KEY_LOW,
        MaybeRelocatable::Int(Felt252::from(key_low)),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    insert_value_from_var_name(
        vars::ids::KEY_HIGH,
        MaybeRelocatable::Int(Felt252::from(key_high)),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const HINT_GET_MPT_PROOF: &str = "proof = account[\"proofs\"][ids.proof_idx] ids.block_number = proof[\"block_number\"] segments.write_arg(ids.mpt_proof, nested_hex_to_int_array(proof[\"proof\"])) segments.write_arg(ids.proof_bytes_len, proof[\"proof_bytes_len\"]) ids.proof_len = len(proof[\"proof\"])";

pub fn hint_get_mpt_proof(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // TODO: Retrieve `account["proofs"][proof_idx]` when supported.
    let _proof = "";

    // TODO: Retrieve `proof["block_number"]` when supported.
    let block_number = Felt252::from(0);
    insert_value_from_var_name(
        vars::ids::BLOCK_NUMBER,
        MaybeRelocatable::Int(block_number),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let mpt_proof_ptr = get_ptr_from_var_name(
        vars::ids::MPT_PROOF,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    let nested_hex_array: &[&[&str]] = &[&[]];
    vm.write_arg(mpt_proof_ptr, &nested_hex_to_int_array(nested_hex_array))?;

    let proof_bytes_len_ptr = get_ptr_from_var_name(
        vars::ids::PROOF_BYTES_LEN,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    // TODO: Retrieve `proof["proof_bytes_len"]` when supported.
    vm.write_arg(proof_bytes_len_ptr, &0)?;

    Ok(())
}
