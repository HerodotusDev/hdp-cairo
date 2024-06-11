from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.types import Receipt
from src.rlp import rlp_list_retrieve, le_chunks_to_uint256
from src.chain_info import ChainInfo
from starkware.cairo.common.uint256 import Uint256

namespace ReceiptField {
    const SUCCESS = 0;
    const CUMULATIVE_GAS_USED = 1;
    const BLOOM = 2;
    const LOGS = 3;
}

namespace ReceiptDecoder {
    func get_field{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, chain_info: ChainInfo, pow2_array: felt*
    }(receipt: Receipt, field: felt) -> Uint256 {
        alloc_locals;
        if (field == ReceiptField.LOGS) {
            assert 1 = 0;  // returns as felt
        }

        if (field == ReceiptField.BLOOM) {
            assert 1 = 0;  // returns as felt
        }

        if (field == ReceiptField.SUCCESS) {
            local is_byzantium: felt;
            %{
                if ids.receipt.block_number >= ids.chain_info.byzantium:
                    ids.is_byzantium = 1
                else:
                    ids.is_byzantium = 0
            %}

            if (is_byzantium == 0) {
                assert 1 = 0;  // we dont have a status for pre-byzantium
            }
            assert [range_check_ptr] = receipt.block_number - chain_info.byzantium;
            tempvar range_check_ptr = range_check_ptr + 1;
        } else {
            tempvar range_check_ptr = range_check_ptr;
        }

        let (res, res_len, bytes_len) = rlp_list_retrieve(receipt.rlp, field, 0, 0);
        let field_value = le_chunks_to_uint256(res, res_len, bytes_len);
        return field_value;
    }

    func get_felt_field{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, chain_info: ChainInfo
    }(receipt: Receipt, field) -> (value: felt*, value_len: felt, bytes_len: felt) {
        alloc_locals;
        if (field == ReceiptField.SUCCESS) {
            local is_byzantium: felt;
            %{
                if ids.receipt.block_number >= ids.chain_info.byzantium:
                    ids.is_byzantium = 1
                else:
                    ids.is_byzantium = 0
            %}

            if (is_byzantium == 0) {
                assert 1 = 0;  // we dont have a status for pre-byzantium
            }
            assert [range_check_ptr] = receipt.block_number - chain_info.byzantium;
            tempvar range_check_ptr = range_check_ptr + 1;
        } else {
            tempvar range_check_ptr = range_check_ptr;
        }

        let (res, res_len, bytes_len) = rlp_list_retrieve(receipt.rlp, field, 0, 0);
        return (res, res_len, bytes_len);
    }
}
