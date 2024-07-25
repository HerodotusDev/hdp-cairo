from starkware.cairo.common.alloc import alloc
from src.decoders.storage_slot_decoder import StorageSlotDecoder
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location

// This is not used but stays for reference
namespace StorageMemorizerFunctionId {
    const GET_SLOT = 0;
}

func get_memorizer_handler_ptrs() -> felt** {
    let (handler_list) = alloc();
    let handler_ptrs = cast(handler_list, felt**);

    let (label) = get_label_location(get_slot_value);
    assert handler_ptrs[StorageMemorizerFunctionId.GET_SLOT] = label;

    return handler_ptrs;
}

func get_slot_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = StorageSlotDecoder.get_word(rlp=rlp);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}
