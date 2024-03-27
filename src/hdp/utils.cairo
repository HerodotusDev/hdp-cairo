from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256s

from src.libs.utils import (
    word_reverse_endian_16_RC,
    word_reverse_endian_24_RC,
    word_reverse_endian_32_RC,
    word_reverse_endian_40_RC,
    word_reverse_endian_48_RC,
    word_reverse_endian_56_RC
)

// ToDo: deprecate
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

// reverses the endianness of chunk up to 56 bytes long
func reverse_small_chunk_endianess{range_check_ptr}(word: felt, bytes_len: felt) -> felt{
    if(bytes_len == 1) {
        return word;
    }
    if(bytes_len == 2) {
        return word_reverse_endian_16_RC{range_check_ptr=range_check_ptr}(word);
    }
    if(bytes_len == 3) {
        return word_reverse_endian_24_RC{range_check_ptr=range_check_ptr}(word);
    }
    if(bytes_len == 4) {
        return word_reverse_endian_32_RC{range_check_ptr=range_check_ptr}(word);
    }
    if(bytes_len == 5) {
        return word_reverse_endian_40_RC{range_check_ptr=range_check_ptr}(word);
    }
    if(bytes_len == 6) {
        return word_reverse_endian_48_RC{range_check_ptr=range_check_ptr}(word);
    }
    if(bytes_len == 7) {
        return word_reverse_endian_56_RC{range_check_ptr=range_check_ptr}(word);
    }

    assert 1 = 0;
    return 0;
}