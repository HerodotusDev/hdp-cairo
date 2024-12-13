use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

use crate::{
    hint_processor::models::proofs::{transaction::Transaction, Proofs},
    hints::{lib::utils::count_leading_zero_nibbles_from_hex, vars},
};

pub const HINT_BATCH_TRANSACTIONS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.transactions))";

pub fn hint_batch_transactions_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>("batch")?;

    insert_value_into_ap(vm, Felt252::from(batch.transactions.len()))
}

pub const HINT_SET_TX: &str = "transaction = transactions[ids.idx]";

pub fn hint_set_tx(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>("batch")?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let transaction = batch.transactions[idx].clone();

    exec_scopes.insert_value::<Transaction>("transaction", transaction);

    Ok(())
}

pub const HINT_SET_TX_KEY: &str = "from tools.py.utils import split_128\n(ids.key.low, ids.key.high) = split_128(int(transaction.key, 16))";

pub fn hint_set_tx_key(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let transaction = exec_scopes.get::<Transaction>("transaction")?;
    let key = transaction.key;

    let key_as_limbs = key.as_limbs();
    let key_low = key_as_limbs[0] as u128 | ((key_as_limbs[1] as u128) << 64);
    let key_high = key_as_limbs[2] as u128 | ((key_as_limbs[3] as u128) << 64);

    insert_value_from_var_name(
        vars::ids::KEY_LOW,
        Felt252::from(key_low),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    insert_value_from_var_name(
        vars::ids::KEY_HIGH,
        Felt252::from(key_high),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    Ok(())
}

pub const HINT_SET_TX_KEY_LEADING_ZEROS: &str =
    "ids.key_leading_zeros = len(transaction.key.lstrip(\"0x\")) - len(transaction.key.lstrip(\"0x\").lstrip(\"0\"))";

pub fn hint_set_tx_key_leading_zeros(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let transaction = exec_scopes.get::<Transaction>("transaction")?;
    let key_leading_zeros = count_leading_zero_nibbles_from_hex(&format!("{:x}", transaction.key));

    insert_value_from_var_name(
        vars::ids::KEY_LEADING_ZEROS,
        Felt252::from(key_leading_zeros),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_SET_TX_PROOF_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(transaction.proof))";

pub fn hint_set_tx_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let transaction = exec_scopes.get::<Transaction>("transaction")?;

    insert_value_into_ap(vm, Felt252::from(transaction.proof.proof.len()))
}

pub const HINT_SET_TX_BLOCK_NUMBER: &str = "memory[ap] = to_felt_or_relocatable(transaction.block_number)";

pub fn hint_set_tx_block_number(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let transaction = exec_scopes.get::<Transaction>("transaction")?;

    insert_value_into_ap(vm, Felt252::from(transaction.proof.block_number))
}

pub const HINT_PROOF_BYTES_LEN: &str = "segments.write_arg(ids.proof_bytes_len, transaction.proof_bytes_len)";

pub fn hint_proof_bytes_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let transaction = exec_scopes.get::<Transaction>("transaction")?;

    let proof_bytes_len_ptr = get_ptr_from_var_name(vars::ids::PROOF_BYTES_LEN, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.insert_value(proof_bytes_len_ptr, Felt252::from(transaction.proof.proof_bytes_len))?;

    Ok(())
}

pub const HINT_MPT_PROOF: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in transaction.proof])";

pub fn hint_mpt_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let transaction = exec_scopes.get::<Transaction>("transaction")?;

    let mpt_proof_ptr = get_ptr_from_var_name(vars::ids::MPT_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    vm.write_arg(mpt_proof_ptr, &transaction.proof.proof)?;

    Ok(())
}
