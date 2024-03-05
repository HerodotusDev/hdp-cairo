from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from src.libs.utils import (
    word_reverse_endian_64, 
    word_reverse_endian_16_RC, 
    word_reverse_endian_24_RC,
    word_reverse_endian_32_RC,
    word_reverse_endian_40_RC,
    word_reverse_endian_48_RC,
    word_reverse_endian_56_RC,
)
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256s

from src.libs.rlp_little import extract_byte_at_pos, extract_n_bytes_from_le_64_chunks_array

// Converts LE 8-byte chunks to BE Uint256
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
            low=low_1 * pow2_array[bytes_len - 1] + low_2,
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
        high=high_1 * pow2_array[bytes_len - 1] + high_2
    );
    return result;
    
}

// ToDo: Investigate endianess again. This works though
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

// Converts a LE 8-bytes chunks to BE 8-bytes chunks. Converts between [1-8] chunks
// The function will break if values[-1] > any other value chunk. (last value must be shorter than the rest)
// Inputs:
// - values: the le 8-bytes chunks
// - values_len: the number of chunks
// - remaining_bytes_len: the number of bytes left to process
// - index: the current index
// - result: the result array
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

        assert values_len = index + 1;
        return ();
    }
    if (remaining_bytes_len == 2) {
        let reversed = word_reverse_endian_16_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;

        assert values_len = index + 1;
        return ();
    }
    if (remaining_bytes_len == 3) {
        let reversed = word_reverse_endian_24_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;

        assert values_len = index + 1;
        return ();
    }
    if (remaining_bytes_len == 4) {
        let reversed = word_reverse_endian_32_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;

        assert values_len = index + 1;
        return ();
    }
    if (remaining_bytes_len == 5) {
        let reversed = word_reverse_endian_40_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;

        assert values_len = index + 1;
        return ();
    }
    if (remaining_bytes_len == 6) {
        let reversed = word_reverse_endian_48_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;

        assert values_len = index + 1;
        return ();
    }
    if (remaining_bytes_len == 7) {
        let reversed = word_reverse_endian_56_RC(values[index]);
        tempvar range_check_ptr = range_check_ptr;
        assert [result] = reversed;

        assert values_len = index + 1;
        return ();
    }

    let val = values[index];
    let (reversed) = word_reverse_endian_64(values[index]);

    assert [result] = reversed;
    return reverse_word_endianness(values=values, values_len=values_len, remaining_bytes_len=remaining_bytes_len-8, index=index + 1, result=result+1);
    
}

// computes the result entry. This maps the result to a task_hash/id. It computes h(task_hash, result), which is a leaf in the results tree.
// Inputs:
// - task_hash: the task hash
// - result: the result
// Outputs:
// - the result entry
func compute_results_entry{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
} (task_hash: Uint256, result: Uint256) -> Uint256 {
    alloc_locals;

    // before hashing we need to reverse the endianness
    let (result_le) = uint256_reverse_endian(result);

    let (values_uint: Uint256*) = alloc();
    assert [values_uint] = task_hash;
    assert [values_uint + Uint256.SIZE] = result_le;

    let (values_felt) = alloc();
    let values_felt_start = values_felt;

    // convert to felts
    keccak_add_uint256s{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        inputs=values_felt
    }(
        n_elements=2,
        elements=values_uint,
        bigend=0
    );

    let (res_id) = keccak(values_felt_start, 64);

    return (res_id);
}

// decodes an rlp word to a uint256
// Inputs:
// - elements: u64 le chunks containing the rlp word
// - elements_bytes_len: the number of bytes of the elements
// Outputs:
// - the decoded uint256
func decode_rlp_word_to_uint256{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(elements: felt*, elements_bytes_len: felt) -> Uint256 {
    alloc_locals;
    // if its a single byte, we can just return it
    if (elements_bytes_len == 1) {
        let result = Uint256(
            low=elements[0],
            high=0
        );
        return result;
    }

    // fetch length from rlp prefix
    let prefix = extract_byte_at_pos(elements[0], 0, pow2_array);
    local result_bytes_len = prefix - 0x80; // works since word has max. 32 bytes

    let (result_chunks, result_len) = extract_n_bytes_from_le_64_chunks_array(
        array=elements,
        start_word=0,
        start_offset=1, // skip the prefix
        n_bytes=result_bytes_len,
        pow2_array=pow2_array
    );

    // convert to uint256
    let result = uint_le_u64_array_to_uint256(
        elements=result_chunks,
        elements_len=result_len,
        bytes_len=result_bytes_len
    );

    return result;
}