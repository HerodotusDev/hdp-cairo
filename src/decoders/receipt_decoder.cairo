from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.types import Receipt
from src.rlp import rlp_list_retrieve, le_chunks_to_uint256
from starkware.cairo.common.uint256 import Uint256

namespace ReceiptField {
    const SUCCESS = 0;
    const CUMULATIVE_GAS_USED = 1;
    const LOGS = 2;
    const BLOOM = 3;
}

namespace ReceiptDecoder {

    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        receipt: Receipt, field: felt
    ) -> Uint256 {
        if (field == ReceiptField.LOGS) {
            assert 1 = 0;  // returns as felt
        }
        
        if (field == ReceiptField.BLOOM) {
            assert 1 = 0;  // returns as felt
        }

        let (res, res_len, bytes_len) = rlp_list_retrieve(receipt.rlp, field, 0, 0);
        return le_chunks_to_uint256(res, res_len, bytes_len);
    }

     func get_felt_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        receipt: Receipt, field
    ) -> (value: felt*, value_len: felt, bytes_len: felt) {

        let (res, res_len, bytes_len) = rlp_list_retrieve(receipt.rlp, field, 0, 0);
        return (res, res_len, bytes_len);
    }

}