from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.utils.chain_info import ChainInfo
from src.utils.chain_info import fetch_chain_info
from src.utils.rlp import rlp_list_retrieve, le_chunks_to_be_uint256, get_rlp_list_meta, get_rlp_len, decode_rlp_word_to_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256

const LOGS = 3;

namespace ReceiptField {
    const SUCCESS = 0;
    const CUMULATIVE_GAS_USED = 1;
    const BLOOM = 2;
    const LOGS_ADDRESS = LOGS + 0;
    const LOGS_TOPIC0 = LOGS + 1;
    const LOGS_TOPIC1 = LOGS + 2;
    const LOGS_TOPIC2 = LOGS + 3;
    const LOGS_TOPIC3 = LOGS + 4;
    const LOGS_TOPIC4 = LOGS + 5;
    const LOGS_DATA = LOGS + 6;
}

namespace ReceiptDecoder {
    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*,
        field: felt,
        rlp_start_offset: felt,
        tx_type: felt,
        block_number: felt,
        chain_id: felt,
    ) -> (res_array: felt*, res_len: felt) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);

        if (field == ReceiptField.LOGS_ADDRESS) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 0, value_start_offset, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == ReceiptField.LOGS_TOPIC0) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 1, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, ReceiptField.LOGS_TOPIC0 - LOGS - 1, 0, 0);
            %{ print rlp %}
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == ReceiptField.LOGS_TOPIC1) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 1, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, ReceiptField.LOGS_TOPIC1  - LOGS - 1, 0, 0);
            %{ print rlp %}
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == ReceiptField.LOGS_TOPIC2) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 1, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, ReceiptField.LOGS_TOPIC2  - LOGS - 1, 0, 0);
            %{ print rlp %}
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == ReceiptField.LOGS_TOPIC3) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 1, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, ReceiptField.LOGS_TOPIC3  - LOGS - 1, 0, 0);
            %{ print rlp %}
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == ReceiptField.LOGS_TOPIC4) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 1, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, ReceiptField.LOGS_TOPIC4  - LOGS - 1, 0, 0);
            %{ print rlp %}
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == ReceiptField.LOGS_DATA) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS, value_start_offset, 0);
            let (local value_start_offset) = get_rlp_list_meta(res, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, 1, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, ReceiptField.LOGS_DATA  - LOGS - 1, 0, 0);
            %{ print rlp %}
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        let (chain_info) = fetch_chain_info(chain_id);

        local is_byzantium: felt;
        %{
            if ids.block_number >= ids.chain_info.byzantium:
                ids.is_byzantium = 1
            else:
                ids.is_byzantium = 0
        %}

        if (is_byzantium == 0) {
            assert [range_check_ptr] = chain_info.byzantium - block_number;
            assert 1 = 0;  // we dont have a status for pre-byzantium
            tempvar range_check_ptr = range_check_ptr + 1;
        } else {
            tempvar range_check_ptr = range_check_ptr;
        }

        assert [range_check_ptr] = block_number - chain_info.byzantium;
        tempvar range_check_ptr = range_check_ptr + 1;

        let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field, value_start_offset, 0);
        let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
        return (res_array=&result, res_len=2);
    }

    // Opens the EIP-2718 transaction envelope for receipts. It returns the transaction type and the index where the RLP-encoded payload starts.
    // Inputs:
    // - item: The eveloped receipt
    // Outputs:
    // - tx_type: The type of the transaction
    // - rlp_start_offset: The index where the RLP-encoded payload starts
    func open_receipt_envelope{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        item: felt*
    ) -> (tx_type: felt, rlp_start_offset: felt) {
        alloc_locals;

        let first_byte = extract_byte_at_pos(item[0], 0, pow2_array);
        let second_byte = extract_byte_at_pos(item[0], 1, pow2_array);

        local has_type_prefix: felt;
        %{
            # typed transactions have a type prefix in this range [1, 3]
            if 0x0 < ids.first_byte < 0x04:
                ids.has_type_prefix = 1
            else:
                ids.has_type_prefix = 0
        %}

        if (has_type_prefix == 1) {
            assert [range_check_ptr] = 0x3 - first_byte;
            assert [range_check_ptr + 1] = first_byte - 1;
            // Can be a long or short list
            assert [range_check_ptr + 2] = 0xff - second_byte;
            assert [range_check_ptr + 3] = second_byte - 0xc0;

            tempvar range_check_ptr = range_check_ptr + 4;
            return (tx_type=first_byte, rlp_start_offset=1);
        } else {
            // Legacy transactions must start with long list prefix
            assert [range_check_ptr] = 0xff - first_byte;
            assert [range_check_ptr + 1] = first_byte - 0xc0;

            tempvar range_check_ptr = range_check_ptr + 2;
            return (tx_type=0, rlp_start_offset=0);
        }
    }
}
