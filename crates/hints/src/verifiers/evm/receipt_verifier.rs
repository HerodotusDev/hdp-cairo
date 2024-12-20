use crate::{utils::{count_leading_zero_nibbles_from_hex, split_128}, vars};
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
use types::proofs::{receipt::Receipt, Proofs};

pub const HINT_BATCH_RECEIPTS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.receipts))";

pub fn hint_batch_receipts_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;

    insert_value_into_ap(vm, Felt252::from(batch.transaction_receipts.len()))
}

pub const HINT_SET_RECEIPT: &str = "receipt = receipts[ids.idx]";

pub fn hint_set_receipt(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let receipt = batch.transaction_receipts[idx].clone();

    exec_scopes.insert_value::<Receipt>(vars::scopes::RECEIPT, receipt);

    Ok(())
}

pub const HINT_RECEIPT_KEY: &str = "from tools.py.utils import split_128\n(ids.key.low, ids.key.high) = split_128(int(receipt.key, 16))";

pub fn hint_receipt_key(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let receipt = exec_scopes.get::<Receipt>(vars::scopes::RECEIPT)?;

    let (key_low, key_high) = split_128(&BigUint::from_bytes_be(&receipt.key.to_be_bytes_vec()));

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

pub const HINT_RECEIPT_KEY_LEADING_ZEROS: &str =
    "ids.key_leading_zeros = len(receipt.key.lstrip(\"0x\")) - len(receipt.key.lstrip(\"0x\").lstrip(\"0\"))";

pub fn hint_receipt_key_leading_zeros(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let receipt = exec_scopes.get::<Receipt>(vars::scopes::RECEIPT)?;
    let key_leading_zeros = count_leading_zero_nibbles_from_hex(&format!("{:x}", receipt.key));

    insert_value_from_var_name(
        vars::ids::KEY_LEADING_ZEROS,
        MaybeRelocatable::Int(Felt252::from(key_leading_zeros)),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_RECEIPT_PROOF_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(receipt.proof))";

pub fn hint_receipt_proof_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let receipt = exec_scopes.get::<Receipt>(vars::scopes::RECEIPT)?;

    insert_value_into_ap(vm, Felt252::from(receipt.proof.proof.len()))
}

pub const HINT_RECEIPT_BLOCK_NUMBER: &str = "memory[ap] = to_felt_or_relocatable(receipt.block_number)";

pub fn hint_receipt_block_number(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let receipt = exec_scopes.get::<Receipt>(vars::scopes::RECEIPT)?;

    insert_value_into_ap(vm, Felt252::from(receipt.proof.block_number))
}

pub const HINT_RECEIPT_PROOF_BYTES_LEN: &str = "segments.write_arg(ids.proof_bytes_len, receipt.proof_bytes_len)";

pub fn hint_receipt_proof_bytes_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let receipt = exec_scopes.get::<Receipt>(vars::scopes::RECEIPT)?;

    insert_value_from_var_name(
        vars::ids::PROOF_BYTES_LEN,
        MaybeRelocatable::Int(Felt252::from(receipt.proof.proof.len())),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const HINT_RECEIPT_MPT_PROOF: &str = "segments.write_arg(ids.mpt_proof, [int(x, 16) for x in receipt.proof])";

pub fn hint_receipt_mpt_proof(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let receipt = exec_scopes.get::<Receipt>(vars::scopes::RECEIPT)?;
    let mpt_proof_ptr = get_ptr_from_var_name(vars::ids::MPT_PROOF, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let proof_le_chunks: Vec<Vec<MaybeRelocatable>> = receipt
        .proof
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
