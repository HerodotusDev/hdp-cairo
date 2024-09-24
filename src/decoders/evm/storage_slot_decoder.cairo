from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from src.rlp import decode_rlp_word_to_uint256

namespace StorageSlotDecoder {
    func get_word{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, _field: felt
    ) -> Uint256 {
        return decode_rlp_word_to_uint256(rlp=rlp);
    }
}
