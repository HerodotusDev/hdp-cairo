from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from src.utils.rlp import decode_rlp_word_to_uint256

namespace StorageSlotDecoder {
    func get_word{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, _field: felt
    ) -> Uint256 {
        let le_value =  decode_rlp_word_to_uint256(rlp=rlp);
        let (be_value) = uint256_reverse_endian(low=le_value.low, high=le_value.high);
        return be_value;
    }
}
