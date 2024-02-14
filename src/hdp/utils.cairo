from starkware.cairo.common.uint256 import Uint256
from src.libs.utils import (
    word_reverse_endian_64, 
    word_reverse_endian_16_RC, 
    word_reverse_endian_24_RC,
    word_reverse_endian_32_RC,
    word_reverse_endian_40_RC,
    word_reverse_endian_48_RC,
    word_reverse_endian_56_RC,
)
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc


func uint_le_u64_array_to_uint256{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (elements: felt*, elements_len: felt, bytes_len: felt) -> Uint256 {
    alloc_locals;
    
    let (local reversed_elements: felt*) = alloc();
    reverse_word_endianness(
        values=elements,
        values_len=elements_len,
        remaining_bytes_len=bytes_len,
        index=0,
        result=reversed_elements
    );

    if (elements_len == 1) {
        let low = reversed_elements[0];
        let result = Uint256(
            low=low,
            high=0
        );
        return result;
    }

    if (elements_len == 2) {
        let low_1 = reversed_elements[0];
        let low_2 = reversed_elements[1];
        let result = Uint256(
            low=low_1 * pow2_array[64] + low_2,
            high=0
        );
        return result;
    }
    
    if (elements_len == 3) {
        let high = reversed_elements[0];
        let low_1 = reversed_elements[1];
        let low_2 = reversed_elements[2];
        let result = Uint256(
            low=low_1 * pow2_array[64] + low_2,
            high=high
        );
        return result;
    }
    
    // ensure we dont overflow
    assert elements_len = 4;

    let high_1 = reversed_elements[0];
    let high_2 = reversed_elements[1];
    let low_1 = reversed_elements[2];
    let low_2 = reversed_elements[3];

    let result = Uint256(
        low=low_1 * pow2_array[64] + low_2,
        high=high_1 * pow2_array[64] + high_2
    );
    return result;
    
}

func keccak_hash_array_to_uint256{
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (elements: felt*, elements_len: felt) -> Uint256 {
    assert elements_len = 4;

    let low_1 = elements[1];
    let low_2 = elements[0];
    let high_1 = elements[3];
    let high_2 = elements[2];

    let result = Uint256(
        low=low_1 * pow2_array[64] + low_2,
        high=high_1 * pow2_array[64] + high_2
    );
    return result;
    
}

// function to convert le byte array chunks to be.
// the chunks can be up to 8 bytes large
// this will break, if the any value is smaller then the last value in the array
func reverse_word_endianness{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
}(values: felt*, values_len: felt,  remaining_bytes_len: felt, index: felt, result: felt*) {
    alloc_locals;
    if(values_len == index) {
        return ();
    }

    if (remaining_bytes_len == 1) {
        let res = values[index];
        assert [result] = res;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-1, index=index + 1, result=result);
    }
    if (remaining_bytes_len == 2) {
        let reversed = word_reverse_endian_16_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-2, index=index + 1, result=result);
    }
    if (remaining_bytes_len == 3) {
        let reversed = word_reverse_endian_24_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-3, index=index + 1, result=result);
    }
    if (remaining_bytes_len == 4) {
        let reversed = word_reverse_endian_32_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-4, index=index + 1, result=result);
    }
    if (remaining_bytes_len == 5) {
        let reversed = word_reverse_endian_40_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-5, index=index + 1, result=result);
    }
    if (remaining_bytes_len == 6) {
        let reversed = word_reverse_endian_48_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-6, index=index + 1, result=result);
    }
    if (remaining_bytes_len == 7) {
        let reversed = word_reverse_endian_56_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;
        return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-7, index=index + 1, result=result);
    }

    let val = values[index];
    let (reversed) = word_reverse_endian_64(values[index]);

    assert [result] = reversed;
    return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-8, index=index + 1, result=result+1);
    
}