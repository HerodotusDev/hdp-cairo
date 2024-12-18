use cairo_vm::{
    hint_processor::{builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData, hint_processor_definition::HintExtension},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

pub mod contract_bootloader;
pub mod decoder;
pub mod merkle;
pub mod print;
pub mod rlp;
pub mod segments;
pub mod utils;
pub mod vars;
pub mod verifiers;

pub type HintImpl = fn(&mut VirtualMachine, &mut ExecutionScopes, &HintProcessorData, &HashMap<String, Felt252>) -> Result<(), HintError>;

/// Hint Extensions extend the current map of hints used by the VM.
/// This behaviour achieves what the `vm_load_data` primitive does for cairo-lang
/// and is needed to implement os hints like `vm_load_program`.
pub type ExtensiveHintImpl =
    fn(&mut VirtualMachine, &mut ExecutionScopes, &HintProcessorData, &HashMap<String, Felt252>) -> Result<HintExtension, HintError>;

#[rustfmt::skip]
pub fn hints() -> HashMap<String, HintImpl> {
    let mut hints = HashMap::<String, HintImpl>::new();
    hints.insert(contract_bootloader::contract_class::LOAD_CONTRACT_CLASS.into(), contract_bootloader::contract_class::load_contract_class);
    hints.insert(contract_bootloader::dict_manager::DICT_MANAGER_CREATE.into(), contract_bootloader::dict_manager::dict_manager_create);
    hints.insert(contract_bootloader::params::LOAD_PARMAS.into(), contract_bootloader::params::load_parmas);
    hints.insert(contract_bootloader::builtins::UPDATE_BUILTIN_PTRS.into(), contract_bootloader::builtins::update_builtin_ptrs);
    hints.insert(contract_bootloader::builtins::SELECTED_BUILTINS.into(), contract_bootloader::builtins::selected_builtins);
    hints.insert(contract_bootloader::builtins::SELECT_BUILTIN.into(), contract_bootloader::builtins::select_builtin);
    hints.insert(decoder::evm::has_type_prefix::HINT_HAS_TYPE_PREFIX.into(), decoder::evm::has_type_prefix::hint_has_type_prefix);
    hints.insert(decoder::evm::is_byzantium::HINT_IS_BYZANTIUM.into(), decoder::evm::is_byzantium::hint_is_byzantium);
    hints.insert(decoder::evm::v_is_encoded::HINT_V_IS_ENCODED.into(), decoder::evm::v_is_encoded::hint_v_is_encoded);
    hints.insert(merkle::HINT_TARGET_TASK_HASH.into(), merkle::hint_target_task_hash);
    hints.insert(merkle::HINT_IS_LEFT_SMALLER.into(), merkle::hint_is_left_smaller);
    hints.insert(rlp::divmod::HINT_DIVMOD_VALUE.into(), rlp::divmod::hint_divmod_value);
    hints.insert(rlp::divmod::HINT_DIVMOD_RLP.into(), rlp::divmod::hint_divmod_rlp);
    hints.insert(rlp::item_type::HINT_IS_LONG.into(), rlp::item_type::hint_is_long);
    hints.insert(rlp::item_type::HINT_ITEM_TYPE.into(), rlp::item_type::hint_item_type);
    hints.insert(rlp::processed_words::HINT_PROCESSED_WORDS.into(), rlp::processed_words::hint_processed_words);
    hints.insert(print::PROGRAM_HASH.into(), print::program_hash);
    hints.insert(segments::SEGMENTS_ADD.into(), segments::segments_add);
    hints.insert(segments::SEGMENTS_ADD_EVM_MEMORIZER_SEGMENT_INDEX.into(), segments::segments_add_evm_memorizer_segment_index);
    hints.insert(segments::SEGMENTS_ADD_EVM_MEMORIZER_OFFSET.into(), segments::segments_add_evm_memorizer_offset);
    hints.insert(segments::SEGMENTS_ADD_EVM_STARKNET_MEMORIZER_INDEX.into(), segments::segments_add_evm_starknet_memorizer_index);
    hints.insert(segments::SEGMENTS_ADD_STARKNET_MEMORIZER_OFFSET.into(), segments::segments_add_starknet_memorizer_offset);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_KEY.into(), verifiers::evm::account_verifier::hint_account_key);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_KEY_LEADING_ZEROS.into(), verifiers::evm::account_verifier::hint_account_key_leading_zeros);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_AT.into(), verifiers::evm::account_verifier::hint_account_proof_at);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_BLOCK_NUMBER.into(), verifiers::evm::account_verifier::hint_account_proof_block_number);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_BYTES_LEN.into(), verifiers::evm::account_verifier::hint_account_proof_bytes_len);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOFS_LEN.into(), verifiers::evm::account_verifier::hint_account_proofs_len);
    hints.insert(verifiers::evm::account_verifier::HINT_BATCH_ACCOUNTS_LEN.into(), verifiers::evm::account_verifier::hint_batch_accounts_len);
    hints.insert(verifiers::evm::account_verifier::HINT_GET_ACCOUNT_ADDRESS.into(), verifiers::evm::account_verifier::hint_get_account_address);
    hints.insert(verifiers::evm::account_verifier::HINT_GET_MPT_PROOF.into(), verifiers::evm::account_verifier::hint_get_mpt_proof);
    hints.insert(verifiers::evm::transaction_verifier::HINT_BATCH_TRANSACTIONS_LEN.into(), verifiers::evm::transaction_verifier::hint_batch_transactions_len);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX.into(), verifiers::evm::transaction_verifier::hint_set_tx);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_KEY.into(), verifiers::evm::transaction_verifier::hint_set_tx_key);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_KEY_LEADING_ZEROS.into(), verifiers::evm::transaction_verifier::hint_set_tx_key_leading_zeros);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_PROOF_LEN.into(), verifiers::evm::transaction_verifier::hint_set_tx_proof_len);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_BLOCK_NUMBER.into(), verifiers::evm::transaction_verifier::hint_set_tx_block_number);
    hints.insert(verifiers::evm::transaction_verifier::HINT_PROOF_BYTES_LEN.into(), verifiers::evm::transaction_verifier::hint_proof_bytes_len);
    hints.insert(verifiers::evm::transaction_verifier::HINT_MPT_PROOF.into(), verifiers::evm::transaction_verifier::hint_mpt_proof);
    hints.insert(verifiers::evm::header_verifier::HINT_LEAF_IDX.into(), verifiers::evm::header_verifier::hint_leaf_idx);
    hints.insert(verifiers::evm::header_verifier::HINT_MMR_PATH_LEN.into(), verifiers::evm::header_verifier::hint_mmr_path_len);
    hints.insert(verifiers::evm::header_verifier::HINT_MMR_PATH.into(), verifiers::evm::header_verifier::hint_mmr_path);
    hints.insert(verifiers::evm::header_verifier::HINT_RLP_LEN.into(), verifiers::evm::header_verifier::hint_rlp_len);
    hints.insert(verifiers::evm::header_verifier::HINT_SET_HEADER.into(), verifiers::evm::header_verifier::hint_set_header);
    hints.insert(verifiers::evm::receipt_verifier::HINT_BATCH_RECEIPTS_LEN.into(), verifiers::evm::receipt_verifier::hint_batch_receipts_len);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_BLOCK_NUMBER.into(), verifiers::evm::receipt_verifier::hint_receipt_block_number);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_KEY.into(), verifiers::evm::receipt_verifier::hint_receipt_key);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_KEY_LEADING_ZEROS.into(), verifiers::evm::receipt_verifier::hint_receipt_key_leading_zeros);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_MPT_PROOF.into(), verifiers::evm::receipt_verifier::hint_receipt_mpt_proof);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_PROOF_LEN.into(), verifiers::evm::receipt_verifier::hint_receipt_proof_len);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_PROOF_BYTES_LEN.into(), verifiers::evm::receipt_verifier::hint_receipt_proof_bytes_len);
    hints.insert(verifiers::evm::receipt_verifier::HINT_SET_RECEIPT.into(), verifiers::evm::receipt_verifier::hint_set_receipt);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_BATCH_STORAGES_LEN.into(), verifiers::evm::storage_item_verifier::hint_batch_storages_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_BATCH_STORAGES.into(), verifiers::evm::storage_item_verifier::hint_set_batch_storages);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_MPT_PROOF.into(), verifiers::evm::storage_item_verifier::hint_set_mpt_proof);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_PROOF_LEN.into(), verifiers::evm::storage_item_verifier::hint_set_proof_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_PROOF_BYTES_LEN.into(), verifiers::evm::storage_item_verifier::hint_set_proof_bytes_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_PROOF_BLOCK_NUMBER.into(), verifiers::evm::storage_item_verifier::hint_set_proof_block_number);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_KEY.into(), verifiers::evm::storage_item_verifier::hint_set_storage_key);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_KEY_LEADING_ZEROS.into(), verifiers::evm::storage_item_verifier::hint_set_storage_key_leading_zeros);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_PROOFS_LEN.into(), verifiers::evm::storage_item_verifier::hint_set_storage_proofs_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_PROOF_AT.into(), verifiers::evm::storage_item_verifier::hint_set_storage_proof_at);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_SLOT.into(), verifiers::evm::storage_item_verifier::hint_set_storage_slot);
    hints.insert(verifiers::verify::HINT_VM_ENTER_SCOPE.into(), verifiers::verify::hint_vm_enter_scope);
    hints.insert(verifiers::utils::HINT_PRINT_TASK_RESULT.into(), verifiers::utils::hint_print_task_result);
    hints
}

#[rustfmt::skip]
pub fn extensive_hints() -> HashMap<String, ExtensiveHintImpl> {
    let mut hints = HashMap::<String, ExtensiveHintImpl>::new();
    hints.insert(contract_bootloader::program::LOAD_PROGRAM.into(), contract_bootloader::program::load_program);
    hints
}
