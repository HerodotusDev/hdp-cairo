from packages.eth_essentials.lib.utils import word_reverse_endian_64
from src.utils.rlp import right_shift_le_chunks
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

func le_address_chunks_to_felt{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    address: felt*
) -> (address: felt) {
    // before we can endian-flip we need to right shift the le values by 4 bytes
    // e.g. [0xaad30603936f2c7f, 0x12f5986a6c3a6b73, 0xd43640f7] -> [0x936f2c7f00000000, 0x6c3a6b73aad30603, 0xd43640f712f5986a]
    let (right_shifted) = right_shift_le_chunks(address, 3, 4);
    let (w0) = word_reverse_endian_64{bitwise_ptr=bitwise_ptr}([right_shifted]);
    let (w1) = word_reverse_endian_64{bitwise_ptr=bitwise_ptr}([right_shifted + 1]);
    let (w2) = word_reverse_endian_64{bitwise_ptr=bitwise_ptr}([right_shifted + 2]);

    return (address=w0 * pow2_array[128] + w1 * pow2_array[64] + w2);
}
