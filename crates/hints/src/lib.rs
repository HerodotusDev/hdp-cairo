use std::collections::HashMap;

use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData, hint_processor_definition::HintExtension,
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

pub mod contract_bootloader;
pub mod decoder;
pub mod merkle;
pub mod patricia;
pub mod print;
pub mod rlp;
pub mod segments;
pub mod utils;
pub mod vars;
pub mod verifiers;

pub type HintImpl = fn(&mut VirtualMachine, &mut ExecutionScopes, &HintProcessorData, &HashMap<String, Felt252>) -> Result<(), HintError>;

/// Hint Extensions extend the current map of hints used by the VM.
/// This behavior achieves what the `vm_load_data` primitive does for cairo-lang
/// and is needed to implement os hints like `vm_load_program`.
pub type ExtensiveHintImpl =
    fn(&mut VirtualMachine, &mut ExecutionScopes, &HintProcessorData, &HashMap<String, Felt252>) -> Result<HintExtension, HintError>;

#[rustfmt::skip]
pub fn hints() -> HashMap<String, HintImpl> {
    let mut hints = HashMap::<String, HintImpl>::new();
    hints.insert(contract_bootloader::builtins::SELECT_BUILTIN.into(), contract_bootloader::builtins::select_builtin);
    hints.insert(contract_bootloader::builtins::SELECTED_BUILTINS.into(), contract_bootloader::builtins::selected_builtins);
    hints.insert(contract_bootloader::builtins::UPDATE_BUILTIN_PTRS.into(), contract_bootloader::builtins::update_builtin_ptrs);
    hints.insert(contract_bootloader::contract_class::LOAD_CONTRACT_CLASS.into(), contract_bootloader::contract_class::load_contract_class);
    hints.insert(contract_bootloader::dict_manager::DICT_MANAGER_CREATE.into(), contract_bootloader::dict_manager::dict_manager_create);
    hints.insert(contract_bootloader::params::INJECTED_STATES_ENTRIES_LEN.into(), contract_bootloader::params::injected_states_entries_len);
    hints.insert(contract_bootloader::params::INJECTED_STATES_SET_KEYS.into(), contract_bootloader::params::injected_states_set_keys);
    hints.insert(contract_bootloader::params::INJECTED_STATES_WRITE_LISTS.into(), contract_bootloader::params::injected_states_write_lists);
    hints.insert(contract_bootloader::params::LOAD_PRIVATE_INPUTS_LEN.into(), contract_bootloader::params::load_private_inputs_len);
    hints.insert(contract_bootloader::params::LOAD_PRIVATE_INPUTS.into(), contract_bootloader::params::load_private_inputs);
    hints.insert(contract_bootloader::params::LOAD_PUBLIC_INPUTS_LEN.into(), contract_bootloader::params::load_public_inputs_len);
    hints.insert(contract_bootloader::params::LOAD_PUBLIC_INPUTS.into(), contract_bootloader::params::load_public_inputs);
    hints.insert(contract_bootloader::params::UNCONSTRAINED_ENTRIES_LEN.into(), contract_bootloader::params::unconstrained_entries_len);
    hints.insert(contract_bootloader::params::UNCONSTRAINED_WRITE_LISTS.into(), contract_bootloader::params::unconstrained_write_lists);
    hints.insert(decoder::evm::has_type_prefix::HINT_HAS_TYPE_PREFIX.into(), decoder::evm::has_type_prefix::hint_has_type_prefix);
    hints.insert(decoder::evm::is_byzantium::HINT_IS_BYZANTIUM.into(), decoder::evm::is_byzantium::hint_is_byzantium);
    hints.insert(decoder::evm::normalize_v::HINT_IS_EIP155.into(), decoder::evm::normalize_v::hint_is_eip155);
    hints.insert(decoder::evm::normalize_v::HINT_IS_SHORT.into(), decoder::evm::normalize_v::hint_is_short);
    hints.insert(decoder::evm::v_is_encoded::HINT_V_IS_ENCODED.into(), decoder::evm::v_is_encoded::hint_v_is_encoded);
    hints.insert(merkle::HINT_IS_LEFT_SMALLER.into(), merkle::hint_is_left_smaller);
    hints.insert(merkle::HINT_TARGET_TASK_HASH.into(), merkle::hint_target_task_hash);
    hints.insert(patricia::hints::ASSERT_CASE_IS_RIGHT.into(), patricia::hints::assert_case_is_right);
    hints.insert(patricia::hints::BUILD_DESCENT_MAP.into(), patricia::hints::build_descent_map);
    hints.insert(patricia::hints::DECODE_NODE_2.into(), patricia::hints::decode_node_hint);
    hints.insert(patricia::hints::DECODE_NODE.into(), patricia::hints::decode_node_hint);
    hints.insert(patricia::hints::ENTER_SCOPE_DESCEND_EDGE.into(), patricia::hints::enter_scope_descend_edge);
    hints.insert(patricia::hints::ENTER_SCOPE_LEFT_CHILD.into(), patricia::hints::enter_scope_left_child);
    hints.insert(patricia::hints::ENTER_SCOPE_NEW_NODE.into(), patricia::hints::enter_scope_new_node);
    hints.insert(patricia::hints::ENTER_SCOPE_NEXT_NODE_BIT_0.into(), patricia::hints::enter_scope_next_node_bit_0);
    hints.insert(patricia::hints::ENTER_SCOPE_NEXT_NODE_BIT_1.into(), patricia::hints::enter_scope_next_node_bit_1);
    hints.insert(patricia::hints::ENTER_SCOPE_NODE.into(), patricia::hints::enter_scope_node_hint);
    hints.insert(patricia::hints::ENTER_SCOPE_RIGHT_CHILD.into(), patricia::hints::enter_scope_right_child);
    hints.insert(patricia::hints::HEIGHT_IS_ZERO_OR_LEN_NODE_PREIMAGE_IS_TWO.into(), patricia::hints::height_is_zero_or_len_node_preimage_is_two);
    hints.insert(patricia::hints::IS_CASE_RIGHT.into(), patricia::hints::is_case_right);
    hints.insert(patricia::hints::LOAD_EDGE.into(), patricia::hints::load_edge);
    hints.insert(patricia::hints::PREPARE_PREIMAGE_VALIDATION_NON_DETERMINISTIC_HASHES.into(), patricia::hints::prepare_preimage_validation_non_deterministic_hashes);
    hints.insert(patricia::hints::SET_AP_TO_DESCEND.into(), patricia::hints::set_ap_to_descend);
    hints.insert(patricia::hints::SET_BIT.into(), patricia::hints::set_bit);
    hints.insert(patricia::hints::SET_SIBLINGS.into(), patricia::hints::set_siblings);
    hints.insert(patricia::hints::SPLIT_DESCEND.into(), patricia::hints::split_descend);
    hints.insert(patricia::hints::WRITE_CASE_NOT_LEFT_TO_AP.into(), patricia::hints::write_case_not_left_to_ap);
    hints.insert(print::HINT_PRINT_TASK_RESULT.into(), print::hint_print_task_result);
    hints.insert(print::MODULE_HASH.into(), print::module_hash);
    hints.insert(rlp::divmod::HINT_DIVMOD_RLP.into(), rlp::divmod::hint_divmod_rlp);
    hints.insert(rlp::divmod::HINT_DIVMOD_VALUE.into(), rlp::divmod::hint_divmod_value);
    hints.insert(rlp::item_type::HINT_IS_LONG.into(), rlp::item_type::hint_is_long);
    hints.insert(rlp::item_type::HINT_ITEM_TYPE.into(), rlp::item_type::hint_item_type);
    hints.insert(rlp::processed_words::HINT_PROCESSED_WORDS_RLP.into(), rlp::processed_words::hint_processed_words_rlp);
    hints.insert(rlp::processed_words::HINT_PROCESSED_WORDS.into(), rlp::processed_words::hint_processed_words);
    hints.insert(segments::MMR_METAS_LEN_COUNTER.into(), segments::mmr_metas_len_counter);
    hints.insert(segments::RETDATA_SIZE_COUNTER.into(), segments::retdata_size_counter);
    hints.insert(segments::SEGMENTS_ADD_EVM_MEMORIZER_OFFSET.into(), segments::segments_add_evm_memorizer_offset);
    hints.insert(segments::SEGMENTS_ADD_EVM_MEMORIZER_SEGMENT_INDEX.into(), segments::segments_add_evm_memorizer_segment_index);
    hints.insert(segments::SEGMENTS_ADD_FP.into(), segments::segments_add_fp);
    hints.insert(segments::SEGMENTS_ADD_INJECTED_STATE_MEMORIZER_INDEX.into(), segments::segments_add_injected_state_memorizer_index);
    hints.insert(segments::SEGMENTS_ADD_INJECTED_STATE_MEMORIZER_OFFSET.into(), segments::segments_add_injected_state_memorizer_offset);
    hints.insert(segments::SEGMENTS_ADD_STARKNET_MEMORIZER_INDEX.into(), segments::segments_add_starknet_memorizer_index);
    hints.insert(segments::SEGMENTS_ADD_STARKNET_MEMORIZER_OFFSET.into(), segments::segments_add_starknet_memorizer_offset);
    hints.insert(segments::SEGMENTS_ADD_UNCONSTRAINED_MEMORIZER_INDEX.into(), segments::segments_add_unconstrained_memorizer_index);
    hints.insert(segments::SEGMENTS_ADD_UNCONSTRAINED_MEMORIZER_OFFSET.into(), segments::segments_add_unconstrained_memorizer_offset);
    hints.insert(segments::SEGMENTS_ADD.into(), segments::segments_add);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_KEY_LEADING_ZEROS.into(), verifiers::evm::account_verifier::hint_account_key_leading_zeros);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_KEY.into(), verifiers::evm::account_verifier::hint_account_key);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_AT.into(), verifiers::evm::account_verifier::hint_account_proof_at);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_BLOCK_NUMBER.into(), verifiers::evm::account_verifier::hint_account_proof_block_number);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_BYTES_LEN.into(), verifiers::evm::account_verifier::hint_account_proof_bytes_len);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOF_LEN.into(), verifiers::evm::account_verifier::hint_account_proof_len);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOFS_LEN.into(), verifiers::evm::account_verifier::hint_account_proofs_len);
    hints.insert(verifiers::evm::account_verifier::HINT_ACCOUNT_PROOFS_LEN.into(), verifiers::evm::account_verifier::hint_account_proofs_len);
    hints.insert(verifiers::evm::account_verifier::HINT_BATCH_ACCOUNTS_LEN.into(), verifiers::evm::account_verifier::hint_batch_accounts_len);
    hints.insert(verifiers::evm::account_verifier::HINT_GET_ACCOUNT_ADDRESS.into(), verifiers::evm::account_verifier::hint_get_account_address);
    hints.insert(verifiers::evm::account_verifier::HINT_GET_MPT_PROOF.into(), verifiers::evm::account_verifier::hint_get_mpt_proof);
    hints.insert(verifiers::evm::header_verifier::HINT_HEADERS_WITH_MMR_HEADERS_LEN.into(), verifiers::evm::header_verifier::hint_headers_with_mmr_headers_len);
    hints.insert(verifiers::evm::header_verifier::HINT_HEADERS_WITH_MMR_LEN.into(), verifiers::evm::header_verifier::hint_headers_with_mmr_len);
    hints.insert(verifiers::evm::header_verifier::HINT_LEAF_IDX.into(), verifiers::evm::header_verifier::hint_leaf_idx);
    hints.insert(verifiers::evm::header_verifier::HINT_MMR_PATH_LEN.into(), verifiers::evm::header_verifier::hint_mmr_path_len);
    hints.insert(verifiers::evm::header_verifier::HINT_MMR_PATH.into(), verifiers::evm::header_verifier::hint_mmr_path);
    hints.insert(verifiers::evm::header_verifier::HINT_RLP_LEN.into(), verifiers::evm::header_verifier::hint_rlp_len);
    hints.insert(verifiers::evm::header_verifier::HINT_SET_HEADER.into(), verifiers::evm::header_verifier::hint_set_header);
    hints.insert(verifiers::evm::header_verifier::HINT_VM_ENTER_SCOPE.into(), verifiers::evm::header_verifier::hint_vm_enter_scope);
    hints.insert(verifiers::evm::HINT_HEADERS_WITH_MMR_LEN.into(), verifiers::evm::hint_headers_with_mmr_len);
    hints.insert(verifiers::evm::HINT_VM_ENTER_SCOPE.into(), verifiers::evm::hint_vm_enter_scope);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_CHAIN_ID.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_chain_id);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_ID.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_id);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_ID.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_id);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_PEAKS_LEN.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_peaks_len);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_PEAKS_LEN.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_peaks_len);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_ROOT.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_root);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_ROOT.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_root);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_SIZE.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_size);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_META_SIZE.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_meta_size);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_PEAKS.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_peaks);
    hints.insert(verifiers::evm::mmr_verifier::HINT_HEADERS_WITH_MMR_PEAKS.into(), verifiers::evm::mmr_verifier::hint_headers_with_mmr_peaks);
    hints.insert(verifiers::evm::receipt_verifier::HINT_BATCH_RECEIPTS_LEN.into(), verifiers::evm::receipt_verifier::hint_batch_receipts_len);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_BLOCK_NUMBER.into(), verifiers::evm::receipt_verifier::hint_receipt_block_number);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_KEY_LEADING_ZEROS.into(), verifiers::evm::receipt_verifier::hint_receipt_key_leading_zeros);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_KEY.into(), verifiers::evm::receipt_verifier::hint_receipt_key);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_MPT_PROOF.into(), verifiers::evm::receipt_verifier::hint_receipt_mpt_proof);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_PROOF_BYTES_LEN.into(), verifiers::evm::receipt_verifier::hint_receipt_proof_bytes_len);
    hints.insert(verifiers::evm::receipt_verifier::HINT_RECEIPT_PROOF_LEN.into(), verifiers::evm::receipt_verifier::hint_receipt_proof_len);
    hints.insert(verifiers::evm::receipt_verifier::HINT_SET_RECEIPT.into(), verifiers::evm::receipt_verifier::hint_set_receipt);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_BATCH_STORAGES_LEN.into(), verifiers::evm::storage_item_verifier::hint_batch_storages_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_BATCH_STORAGES.into(), verifiers::evm::storage_item_verifier::hint_set_batch_storages);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_PROOF_BLOCK_NUMBER.into(), verifiers::evm::storage_item_verifier::hint_set_proof_block_number);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_PROOF_LEN.into(), verifiers::evm::storage_item_verifier::hint_set_proof_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_KEY_LEADING_ZEROS.into(), verifiers::evm::storage_item_verifier::hint_set_storage_key_leading_zeros);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_KEY.into(), verifiers::evm::storage_item_verifier::hint_set_storage_key);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_PROOF_AT.into(), verifiers::evm::storage_item_verifier::hint_set_storage_proof_at);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_PROOFS_LEN.into(), verifiers::evm::storage_item_verifier::hint_set_storage_proofs_len);
    hints.insert(verifiers::evm::storage_item_verifier::HINT_SET_STORAGE_SLOT.into(), verifiers::evm::storage_item_verifier::hint_set_storage_slot);
    hints.insert(verifiers::evm::transaction_verifier::HINT_BATCH_TRANSACTIONS_LEN.into(), verifiers::evm::transaction_verifier::hint_batch_transactions_len);
    hints.insert(verifiers::evm::transaction_verifier::HINT_MPT_PROOF.into(), verifiers::evm::transaction_verifier::hint_mpt_proof);
    hints.insert(verifiers::evm::transaction_verifier::HINT_PROOF_BYTES_LEN.into(), verifiers::evm::transaction_verifier::hint_proof_bytes_len);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_BLOCK_NUMBER.into(), verifiers::evm::transaction_verifier::hint_set_tx_block_number);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_KEY_LEADING_ZEROS.into(), verifiers::evm::transaction_verifier::hint_set_tx_key_leading_zeros);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_KEY.into(), verifiers::evm::transaction_verifier::hint_set_tx_key);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX_PROOF_LEN.into(), verifiers::evm::transaction_verifier::hint_set_tx_proof_len);
    hints.insert(verifiers::evm::transaction_verifier::HINT_SET_TX.into(), verifiers::evm::transaction_verifier::hint_set_tx);
    hints.insert(verifiers::injected_state::HINT_STATE_PROOF_ENTER_SCOPE.into(), verifiers::injected_state::hint_state_proof_enter_scope);
    hints.insert(verifiers::injected_state::HINT_STATE_PROOF_READ_TRIE_LABEL.into(), verifiers::injected_state::hint_state_proof_read_trie_label);
    hints.insert(verifiers::injected_state::HINT_STATE_PROOF_WRITE_TRIE_LABEL.into(), verifiers::injected_state::hint_state_proof_write_trie_label);
    hints.insert(verifiers::injected_state::inclusion::HINT_GET_KEY_BE.into(), verifiers::injected_state::inclusion::hint_get_key_be);
    hints.insert(verifiers::injected_state::inclusion::HINT_GET_TRIE_NODE_PROOF.into(), verifiers::injected_state::inclusion::hint_get_trie_node_proof);
    hints.insert(verifiers::injected_state::inclusion::HINT_INCLUSION_PROOF_LEN.into(), verifiers::injected_state::inclusion::hint_inclusion_proof_len);
    hints.insert(verifiers::injected_state::update::HINT_LEAF_POST_DATA_VALUE.into(), verifiers::injected_state::update::hint_leaf_post_data_value);
    hints.insert(verifiers::injected_state::update::HINT_LEAF_PREV_DATA_VALUE.into(), verifiers::injected_state::update::hint_leaf_prev_data_value);
    hints.insert(verifiers::injected_state::update::HINT_LEAF_PREV_KEY.into(), verifiers::injected_state::update::hint_leaf_prev_key);
    hints.insert(verifiers::injected_state::update::HINT_PREIMAGE.into(), verifiers::injected_state::update::hint_preimage);
    hints.insert(verifiers::injected_state::update::HINT_TRIE_ROOT_POST.into(), verifiers::injected_state::update::hint_trie_root_post);
    hints.insert(verifiers::injected_state::update::HINT_TRIE_ROOT_PREV.into(), verifiers::injected_state::update::hint_trie_root_prev);
    hints.insert(verifiers::mpt::HINT_KECCAK160_BINARY_NODE.into(), verifiers::mpt::hint_keccak160_binary_node);
    hints.insert(verifiers::mpt::HINT_KECCAK160_EDGE_NODE.into(), verifiers::mpt::hint_keccak160_edge_node);
    hints.insert(verifiers::starknet::header_verifier::HINT_FIELDS_LEN.into(), verifiers::starknet::header_verifier::hint_rlp_len);
    hints.insert(verifiers::starknet::header_verifier::HINT_HEADERS_WITH_MMR_HEADERS_LEN.into(), verifiers::starknet::header_verifier::hint_headers_with_mmr_headers_len);
    hints.insert(verifiers::starknet::header_verifier::HINT_HEADERS_WITH_MMR_LEN.into(), verifiers::starknet::header_verifier::hint_headers_with_mmr_len);
    hints.insert(verifiers::starknet::header_verifier::HINT_LEAF_IDX.into(), verifiers::starknet::header_verifier::hint_leaf_idx);
    hints.insert(verifiers::starknet::header_verifier::HINT_MMR_PATH_LEN.into(), verifiers::starknet::header_verifier::hint_mmr_path_len);
    hints.insert(verifiers::starknet::header_verifier::HINT_MMR_PATH.into(), verifiers::starknet::header_verifier::hint_mmr_path);
    hints.insert(verifiers::starknet::header_verifier::HINT_SET_HEADER.into(), verifiers::starknet::header_verifier::hint_set_header);
    hints.insert(verifiers::starknet::header_verifier::HINT_VM_ENTER_SCOPE.into(), verifiers::starknet::header_verifier::hint_vm_enter_scope);
    hints.insert(verifiers::starknet::HINT_HEADERS_WITH_MMR_LEN.into(), verifiers::starknet::hint_headers_with_mmr_len);
    hints.insert(verifiers::starknet::HINT_VM_ENTER_SCOPE.into(), verifiers::starknet::hint_vm_enter_scope);
    hints.insert(verifiers::starknet::mmr_verifier::HINT_HEADERS_WITH_MMR_META_CHAIN_ID.into(), verifiers::starknet::mmr_verifier::hint_headers_with_mmr_meta_chain_id);
    hints.insert(verifiers::starknet::mmr_verifier::HINT_HEADERS_WITH_MMR_META_ID.into(), verifiers::starknet::mmr_verifier::hint_headers_with_mmr_meta_id);
    hints.insert(verifiers::starknet::mmr_verifier::HINT_HEADERS_WITH_MMR_META_PEAKS_LEN.into(), verifiers::starknet::mmr_verifier::hint_headers_with_mmr_meta_peaks_len);
    hints.insert(verifiers::starknet::mmr_verifier::HINT_HEADERS_WITH_MMR_META_ROOT.into(), verifiers::starknet::mmr_verifier::hint_headers_with_mmr_meta_root);
    hints.insert(verifiers::starknet::mmr_verifier::HINT_HEADERS_WITH_MMR_META_SIZE.into(), verifiers::starknet::mmr_verifier::hint_headers_with_mmr_meta_size);
    hints.insert(verifiers::starknet::mmr_verifier::HINT_HEADERS_WITH_MMR_PEAKS.into(), verifiers::starknet::mmr_verifier::hint_headers_with_mmr_peaks);
    hints.insert(verifiers::starknet::storage_verifier::HINT_BATCH_STORAGES_LEN.into(), verifiers::starknet::storage_verifier::hint_batch_storages_len);
    hints.insert(verifiers::starknet::storage_verifier::HINT_NODE_IS_EDGE.into(), verifiers::starknet::storage_verifier::hint_node_is_edge);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_BATCH_STORAGES.into(), verifiers::starknet::storage_verifier::hint_set_batch_storages);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_CONTRACT_ADDRESS.into(), verifiers::starknet::storage_verifier::hint_set_contract_address);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_CONTRACT_NODES.into(), verifiers::starknet::storage_verifier::hint_set_contract_nodes);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_EVAL_DEPTH.into(), verifiers::starknet::storage_verifier::hint_set_eval_depth);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_ADDRESSES_LEN.into(), verifiers::starknet::storage_verifier::hint_set_storage_addresses_len);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_ADDRESSES.into(), verifiers::starknet::storage_verifier::hint_set_storage_addresses);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_BLOCK_NUMBER.into(), verifiers::starknet::storage_verifier::hint_set_storage_block_number);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CLASS_COMMITMENT.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_class_commitment);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_CLASS_HASH.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_contract_data_class_hash);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_CONTRACT_STATE_HASH_VERSION.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_contract_data_contract_state_hash_version);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_NONCE.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_contract_data_nonce);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_STORAGE_PROOF.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_contract_data_storage_proof);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_DATA_STORAGE_PROOFS_LEN.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_contract_data_storage_proofs_len);
    hints.insert(verifiers::starknet::storage_verifier::HINT_SET_STORAGE_STARKNET_PROOF_CONTRACT_PROOF_LEN.into(), verifiers::starknet::storage_verifier::hint_set_storage_starknet_proof_contract_proof_len);
    hints.insert(verifiers::verify::HINT_CHAIN_PROOFS_CHAIN_ID.into(), verifiers::verify::hint_chain_proofs_chain_id);
    hints.insert(verifiers::verify::HINT_CHAIN_PROOFS_LEN.into(), verifiers::verify::hint_chain_proofs_len);
    hints.insert(verifiers::verify::HINT_STATE_PROOFS_LEN.into(), verifiers::verify::hint_state_proofs_len);
    hints.insert(verifiers::verify::HINT_STATE_PROOFS_PROOF_TYPE.into(), verifiers::verify::hint_state_proofs_proof_type);
    hints.insert(verifiers::injected_state::HINT_STATE_PROOF_ENTER_SCOPE.into(), verifiers::injected_state::hint_state_proof_enter_scope);
    hints.insert(verifiers::injected_state::inclusion::HINT_GET_TRIE_NODE_PROOF.into(), verifiers::injected_state::inclusion::hint_get_trie_node_proof);
    hints.insert(verifiers::injected_state::inclusion::HINT_GET_KEY_BE.into(), verifiers::injected_state::inclusion::hint_get_key_be);
    hints.insert(verifiers::injected_state::inclusion::HINT_INCLUSION_PROOF_LEN.into(), verifiers::injected_state::inclusion::hint_inclusion_proof_len);
    hints.insert(verifiers::injected_state::inclusion::HINT_GET_TRIE_ROOT_HASH.into(), verifiers::injected_state::inclusion::hint_get_trie_root_hash);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::bit_length::HINT_BIT_LENGTH.into(), eth_essentials_cairo_vm_hints::hints::lib::bit_length::hint_bit_length);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::mmr::bit_length::MMR_BIT_LENGTH.into(), eth_essentials_cairo_vm_hints::hints::lib::mmr::bit_length::mmr_bit_length);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::mmr::left_child::MMR_LEFT_CHILD.into(), eth_essentials_cairo_vm_hints::hints::lib::mmr::left_child::mmr_left_child);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::mpt::HINT_FIRST_ITEM_TYPE.into(), eth_essentials_cairo_vm_hints::hints::lib::mpt::hint_first_item_type);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::mpt::HINT_ITEM_TYPE.into(), eth_essentials_cairo_vm_hints::hints::lib::mpt::hint_item_type);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::mpt::HINT_LONG_SHORT_LIST.into(), eth_essentials_cairo_vm_hints::hints::lib::mpt::hint_long_short_list);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::mpt::HINT_SECOND_ITEM_TYPE.into(), eth_essentials_cairo_vm_hints::hints::lib::mpt::hint_second_item_type);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::assert::HINT_EXPECTED_LEADING_ZEROES.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::assert::hint_expected_leading_zeroes);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::assert::HINT_EXPECTED_NIBBLE.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::assert::hint_expected_nibble);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::divmod::HINT_POW_CUT.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::divmod::hint_pow_cut);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::leading_zeros::HINT_EXPECTED_LEADING_ZEROES.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::leading_zeros::hint_expected_leading_zeroes);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::leading_zeros::HINT_EXPECTED_NIBBLE.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::leading_zeros::hint_expected_nibble);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::HINT_IS_ZERO.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::hint_is_zero);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::HINT_NEEDS_NEXT_WORD_ENDING.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::hint_needs_next_word_ending);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::HINT_NEEDS_NEXT_WORD.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::hint_needs_next_word);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::HINT_NIBBLE_FROM_LOW.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::hint_nibble_from_low);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::HINT_WORDS_LOOP.into(), eth_essentials_cairo_vm_hints::hints::lib::rlp_little::nibbles::hint_words_loop);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::assert::HINT_ASSERT_INTEGER_DIV.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::assert::hint_assert_integer_div);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::divmod::HINT_VALUE_8.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::divmod::hint_value_8);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::divmod::HINT_VALUE_DIV.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::divmod::hint_value_div);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::trailing_zeroes::HINT_TRAILING_ZEROES_BYTES.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::trailing_zeroes::hint_trailing_zeroes_bytes);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::write::HINT_WRITE_2.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::write::hint_write_2);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::write::HINT_WRITE_3.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::write::hint_write_3);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::write::HINT_WRITE_4.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::write::hint_write_4);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::write::HINT_WRITE_5.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::write::hint_write_5);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::write::HINT_WRITE_6.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::write::hint_write_6);
    hints.insert(eth_essentials_cairo_vm_hints::hints::lib::utils::write::HINT_WRITE_7.into(), eth_essentials_cairo_vm_hints::hints::lib::utils::write::hint_write_7);

    hints.insert(utils::debug::PRINT_DEBUG_BREAKPOINT.into(), utils::debug::print_debug_breakpoint);
    hints.insert(utils::debug::PRINT_FELT_HEX.into(), utils::debug::print_felt_hex);
    hints.insert(utils::debug::PRINT_FELT_HEX.into(), utils::debug::print_felt_hex);
    hints.insert(utils::debug::PRINT_FELT.into(), utils::debug::print_felt);
    hints.insert(utils::debug::PRINT_STRING.into(), utils::debug::print_string);

    hints
}

#[rustfmt::skip]
pub fn extensive_hints() -> HashMap<String, ExtensiveHintImpl> {
    let mut hints = HashMap::<String, ExtensiveHintImpl>::new();
    hints.insert(contract_bootloader::program::LOAD_PROGRAM.into(), contract_bootloader::program::load_program);
    hints
}
