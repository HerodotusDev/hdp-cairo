from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.decoders.evm.transaction_decoder import TransactionType
from src.utils.chain_info import ChainInfo
from src.utils.chain_info import fetch_chain_info
from src.utils.rlp import (
    rlp_list_retrieve,
    le_chunks_to_be_uint256,
    get_rlp_list_meta,
    get_rlp_len,
    decode_rlp_word_to_uint256,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256

struct ReceiptKey {
    chain_id: felt,
    block_number: felt,
    transaction_index: felt,
}

namespace ReceiptField {
    const SUCCESS = 0;
    const CUMULATIVE_GAS_USED = 1;
    const BLOOM = 2;
}

namespace ReceiptDecoder {
    func get_field{
        keccak_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
    }(rlp: felt*, field: felt, key: ReceiptKey*) -> (res_array: felt*, res_len: felt) {
        let (tx_type, rlp_start_offset) = open_receipt_envelope(rlp);
        let (res_array, res_len) = _get_field(rlp, field, rlp_start_offset, tx_type);
        return (res_array=res_array, res_len=res_len);
    }

    func _get_field{
        keccak_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
    }(rlp: felt*, field: felt, rlp_start_offset: felt, tx_type: felt) -> (
        res_array: felt*, res_len: felt
    ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);

        let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field, value_start_offset, 0);

        if (field == ReceiptField.BLOOM) {
            let (local res_array: felt*) = alloc();
            bloom_to_uint256_array(res, res_len, bytes_len, res_array);

            return (res_array=res_array, res_len=bytes_len / 0x20 * 2);
        }

        let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
        return (res_array=&result, res_len=2);
    }

    func bloom_to_uint256_array{
        keccak_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
    }(res: felt*, res_len: felt, bytes_len: felt, res_array: felt*) {
        alloc_locals;

        if (bytes_len == 0) {
            return ();
        }

        let (local result) = le_chunks_to_be_uint256(res, 4, 0x20);
        assert [res_array + 1] = result.low;
        assert [res_array + 0] = result.high;

        return bloom_to_uint256_array(res + 4, res_len - 4, bytes_len - 0x20, res_array + 2);
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
