from starkware.cairo.common.uint256 import Uint256
from src.libs.utils import word_reverse_endian_64
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

// function to convert a little endian u64 array to a uint256. 
// it accepts up to 4x64 byte le chunks, but also handles smaller chunks
func le_u64_array_to_uint256{
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (elements: felt*, elements_len: felt) -> Uint256 {

    if (elements_len == 1) {
        let (low) = word_reverse_endian_64(elements[0]);
        let result = Uint256(
            low=low,
            high=0
        );
        return result;
    }

    if (elements_len == 2) {
        let (low_1) = word_reverse_endian_64(elements[0]);
        let (low_2) = word_reverse_endian_64(elements[1]);
        let result = Uint256(
            low=low_1 * pow2_array[64] + low_2,
            high=0
        );
        return result;
    }
    
    if (elements_len == 3) {
        let (high) = word_reverse_endian_64(elements[0]);
        let (low_1) = word_reverse_endian_64(elements[1]);
        let (low_2) = word_reverse_endian_64(elements[2]);
        let result = Uint256(
            low=low_1 * pow2_array[64] + low_2,
            high=high
        );
        return result;
    }
    
    // ensure we dont overflow
    assert elements_len = 4;

    let (high_1) = word_reverse_endian_64(elements[0]);
    let (high_2) = word_reverse_endian_64(elements[1]);
    let (low_1) = word_reverse_endian_64(elements[2]);
    let (low_2) = word_reverse_endian_64(elements[3]);
    let result = Uint256(
        low=low_1 * pow2_array[64] + low_2,
        high=high_1 * pow2_array[64] + high_2
    );
    return result;
    
}