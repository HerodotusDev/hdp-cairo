from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from src.utils.rlp import rlp_list_retrieve, le_chunks_to_be_uint256, get_rlp_list_meta, get_rlp_len
from src.utils.chain_info import ChainInfo
from starkware.cairo.common.uint256 import Uint256
from src.utils.chain_info import fetch_chain_info
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos

const LONG_SIZE = 4;

namespace ReceiptField {
    const SUCCESS = 0;
    const CUMULATIVE_GAS_USED = 1;
    const BLOOM = 2;
    const TOPIC0 = 3;
    const TOPIC1 = 4;
    const TOPIC2 = 5;
    const TOPIC3 = 6;
    const TOPIC4 = 7;
    const DATA = 8;
}

namespace ReceiptDecoder {
    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*,
        field: felt,
        rlp_start_offset: felt,
        tx_type: felt,
        block_number: felt,
        chain_id: felt,
    ) -> Uint256 {
        alloc_locals;
        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);

        if (field == ReceiptField.TOPIC0) {
            let (local value_start_offset) = get_rlp_list_meta(rlp, value_start_offset + 3 * LONG_SIZE);
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field - ReceiptField.TOPIC0, value_start_offset + 2 * LONG_SIZE, 0);
            let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return uint_res;
        }

        if (field == ReceiptField.TOPIC1) {
            let (local value_start_offset) = get_rlp_list_meta(rlp, value_start_offset + 3 * LONG_SIZE);
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field - ReceiptField.TOPIC0, value_start_offset + 2 * LONG_SIZE, 0);
            let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return uint_res;
        }

        if (field == ReceiptField.TOPIC2) {
            let (local value_start_offset) = get_rlp_list_meta(rlp, value_start_offset + 3 * LONG_SIZE);
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field - ReceiptField.TOPIC0, value_start_offset + 2 * LONG_SIZE, 0);
            let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return uint_res;
        }

        if (field == ReceiptField.TOPIC3) {
            let (local value_start_offset) = get_rlp_list_meta(rlp, value_start_offset + 3 * LONG_SIZE);
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field - ReceiptField.TOPIC0, value_start_offset + 2 * LONG_SIZE, 0);
            let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return uint_res;
        }

        if (field == ReceiptField.TOPIC4) {
            let (local value_start_offset) = get_rlp_list_meta(rlp, value_start_offset + 3 * LONG_SIZE);
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field - ReceiptField.TOPIC0, value_start_offset + 2 * LONG_SIZE, 0);
            let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return uint_res;
        }

        if (field == ReceiptField.DATA) {
            let (local value_start_offset) = get_rlp_list_meta(rlp, value_start_offset + 3 * LONG_SIZE);
            let rlp_len = get_rlp_len(rlp, value_start_offset + 2 * LONG_SIZE);
            let rlp_len = get_rlp_len(rlp, value_start_offset + value_start_offset + rlp_len);
            // return (rlp, rlp_len) list
            return (Uint256(low=0, high=0));
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
        let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
        return uint_res;
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
