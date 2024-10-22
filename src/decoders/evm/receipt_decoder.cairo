from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from src.utils.rlp import rlp_list_retrieve, le_chunks_to_be_uint256, get_rlp_list_meta
from src.utils.chain_info import ChainInfo
from starkware.cairo.common.uint256 import Uint256

from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos

namespace ReceiptField {
    const SUCCESS = 0;
    const CUMULATIVE_GAS_USED = 1;
    const BLOOM = 2;
    const LOGS = 3;
}

namespace ReceiptDecoder {
    func get_field{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, chain_info: ChainInfo, pow2_array: felt*
    }(
        rlp: felt*, field: felt, rlp_start_offset: felt, tx_type: felt, block_number: felt
    ) -> Uint256 {
        alloc_locals;
        if (field == ReceiptField.LOGS) {
            assert 1 = 0;  // returns as felt
        }

        if (field == ReceiptField.BLOOM) {
            assert 1 = 0;  // returns as felt
        }

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

        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);
        let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field, value_start_offset, 0);
        let uint_res = le_chunks_to_be_uint256(res, res_len, bytes_len);
        return uint_res;
    }

    func get_felt_field{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, chain_info: ChainInfo
    }(rlp: felt*, field: felt, rlp_start_offset: felt, tx_type: felt) -> (
        value: felt*, value_len: felt, bytes_len: felt
    ) {
        alloc_locals;
        if (field == ReceiptField.SUCCESS) {
            assert 1 = 0;  // use dedicated function
        }
        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);
        let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field, value_start_offset, 0);

        return (res, res_len, bytes_len);
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
