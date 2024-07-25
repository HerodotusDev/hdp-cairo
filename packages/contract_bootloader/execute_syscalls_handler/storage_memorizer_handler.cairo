from src.decoders.storage_slot_decoder import StorageSlotDecoder
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

// This is not used but stays for reference
namespace StorageMemorizerFunctionId {
    const GET_SLOT = 0;
}

func storage_memorizer_get_slot_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = StorageSlotDecoder.get_word(rlp=rlp);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}
