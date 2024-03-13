from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, word_reverse_endian, uint256_reverse_endian
from src.libs.utils import (
    word_reverse_endian_64, 
    word_reverse_endian_16_RC, 
    word_reverse_endian_24_RC,
    word_reverse_endian_32_RC,
    word_reverse_endian_40_RC,
    word_reverse_endian_48_RC,
    word_reverse_endian_56_RC,
)
from src.libs.utils import felt_divmod

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256s

from src.libs.rlp_little import extract_byte_at_pos, extract_n_bytes_from_le_64_chunks_array, key_subset_to_uint256

// Converts a LE 8-bytes chunks to uint256. Converts between [1-4] chunks
// This function should be used for decoding RLP values, as it can deal with arbitrary length values.
// The to_be flag can be used to convert the result to BE.
func le_u64_array_to_uint256{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (elements: felt*, elements_len: felt, bytes_len: felt, to_be: felt) -> Uint256 {
    alloc_locals;
    local value: Uint256;

    if(elements_len == 1) {
        assert value = Uint256(
            low=elements[0],
            high=0,
        );
    }

    if(elements_len == 2) {
         assert value = Uint256(
            low=elements[1] * pow2_array[64] + elements[0],
            high=0,
        );
    }

    if(elements_len == 3) {
        assert value = Uint256(
            low=elements[1] * pow2_array[64] + elements[0],
            high=elements[2],
        );
    }

    if(elements_len == 4) {
         assert value = Uint256(
            low=elements[1] * pow2_array[64] + elements[0],
            high=elements[3] * pow2_array[64] + elements[2],
        );
    }

    if(to_be == 1) {
        let flipped = bytewise_endian_flip(value, bytes_len);
        return (flipped);
    } else {
        return (value);
    }
}

// Converts a le uint256 to be. This function can deal with a dynamic number of bytes, ensuring no additional padding is added.
// e.g. 0x1234 -> 0x3412 is a valid output for this function. This is required for reversing the endianess of values derived via RLP decoding.
// In contrast, uint256_reverse_endian: 0x1234 -> 0x34120000000000000000000000000000
func bytewise_endian_flip{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (value: Uint256, bytes_len: felt) -> Uint256 {
    
    // value <= 16 bytes
    if(value.high == 0) {
        let (value_low_rev) = word_reverse_endian(value.low);
        let low = value_low_rev / pow2_array[(16 - bytes_len) * 8];

        return (Uint256(
            low=low,
            high=0
        ));
    } else {

        // value >= 17 bytes
        assert [range_check_ptr] = bytes_len - 17;
        let range_check_ptr = range_check_ptr + 1;
        let (value_high_rev) = word_reverse_endian(value.high);
        let (value_low_rev) = word_reverse_endian(value.low);

        let devisor = pow2_array[(32 - bytes_len) * 8];

        let (high, low_left) = felt_divmod(value_low_rev, devisor);
        let (low_right, trash) = felt_divmod(value_high_rev, devisor);
        let low = low_left * pow2_array[(bytes_len - 16) * 8] + low_right;

        return (Uint256(
            low=low,
            high=high
        ));
    }
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
}(elements: felt*, elements_bytes_len: felt, to_be: felt) -> Uint256 { 
    alloc_locals;
    // if its a single byte, we can just return it
    if (elements_bytes_len == 1) {
        return (Uint256(
            low=elements[0],
            high=0
        ));
    }

    // fetch length from rlp prefix
    let prefix = extract_byte_at_pos{
        bitwise_ptr=bitwise_ptr,
    }(elements[0], 0, pow2_array);
    local result_bytes_len = prefix - 0x80; // works since word has max. 32 bytes

    let (result_chunks, result_len) = extract_n_bytes_from_le_64_chunks_array(
        array=elements,
        start_word=0,
        start_offset=1, // skip the prefix
        n_bytes=result_bytes_len,
        pow2_array=pow2_array
    );

    // convert to uint256
    let result = le_u64_array_to_uint256(
        elements=result_chunks,
        elements_len=result_len,
        bytes_len=result_bytes_len,
        to_be=to_be
    );

    return result;
}