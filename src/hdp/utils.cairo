from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
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
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256s

from src.libs.rlp_little import extract_byte_at_pos, extract_n_bytes_from_le_64_chunks_array, key_subset_to_uint256

// Converts LE 8-byte chunks to BE Uint256
func le_u64_array_to_be_uint256{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (elements: felt*, elements_len: felt, bytes_len: felt) -> Uint256 {
    if(elements_len * 8 == bytes_len) {
        return balanced_le_u64_array_to_be_uint256{
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr,
            pow2_array=pow2_array
        }(elements=elements, elements_len=elements_len, bytes_len=bytes_len);
    } else {
        return unbalanced_le_u64_array_to_be_uint256{
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr,
            pow2_array=pow2_array
        }(elements=elements, elements_len=elements_len, bytes_len=bytes_len);
    }
}

// Converts unbalances LE 8-byte chunks to BE Uint256
// If there are more then two elements, this requires mask and shift operations.
// Inputs:
// - elements: the le 8-byte chunks
// - elements_len: the number of chunks
// - bytes_len: the number of bytes
func unbalanced_le_u64_array_to_be_uint256{
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

    // for two elements, we are able to shift based on bytes len
    if (elements_len == 2) {
        let msb = reversed_elements[0];
        let lsb = reversed_elements[1];
        let result = Uint256(
            low=msb * pow2_array[(bytes_len - 8) * 8] + lsb,
            high=0
        );
        return result;
    }

    // Figure out how far we need to shift
    local ls_size: felt;
    %{ 
        ids.ls_size = ids.bytes_len % 8 
    %}
    assert bytes_len = 8 * (elements_len - 1) + ls_size;

    // create masks for left and right side
    let rs_mask = pow2_array[(8 - ls_size) * 8] - 1;
    let ls_mask = (pow2_array[64] - 1) - rs_mask;

    // create shift values
    let l_shift = pow2_array[ls_size * 8];
    let r_shift = pow2_array[(8 - ls_size) * 8];

    let (shifted_values) = alloc();

    mask_and_shift{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        ls_mask=ls_mask,
        rs_mask=rs_mask,
        l_shift=l_shift,
        r_shift=r_shift
    }(values=reversed_elements, results=shifted_values, values_len=elements_len);
    
    if (elements_len == 3) {
        let hlsb = shifted_values[0];
        let lmsb = shifted_values[1];
        let llsb = shifted_values[2];

        let result = Uint256(
            low=lmsb * pow2_array[64] + llsb,
            high=hlsb
        );
        return result;
    }
    
    // ensure we dont overflow
    assert elements_len = 4;

    let hmsb = shifted_values[0];
    let hlsb = shifted_values[1];
    let lmsb = shifted_values[2];
    let llsb = shifted_values[3];

    let result = Uint256(
        low=lmsb * pow2_array[64] + llsb,
        high=hmsb * pow2_array[64] + hlsb
    );
    return result;
}

// Converts a balances LE 8-byte chunks to BE Uint256
// In this case, we just need to reverse the endianness and combine the chunks
func balanced_le_u64_array_to_be_uint256{
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
        let msb = reversed_elements[0];
        let lsb = reversed_elements[1];
        let result = Uint256(
            low=msb * pow2_array[64] + lsb, // for two elements, we can shift conditionaly
            high=0
        );
        return result;
    }

    if (elements_len == 3) {
        let hlsb = reversed_elements[0];
        let lmsb = reversed_elements[1];
        let llsb = reversed_elements[2];

        let result = Uint256(
            low=lmsb * pow2_array[64] + llsb,
            high=hlsb
        );
        return result;
    }

    if (elements_len == 4) {
        let hmsb = reversed_elements[0];
        let hlsb = reversed_elements[1];
        let lmsb = reversed_elements[2];
        let llsb = reversed_elements[3];

        let result = Uint256(
            low=lmsb * pow2_array[64] + llsb,
            high=hmsb * pow2_array[64] + hlsb
        );
        return result;
    }

   assert 1 = 0; // should never reach
   return (Uint256(0, 0));
    
}

// Masks and shifts values according to the masks and shifts provided
func mask_and_shift{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    ls_mask: felt,
    rs_mask: felt,
    l_shift: felt,
    r_shift: felt
}(values: felt*, results: felt*, values_len: felt) {
    alloc_locals;

    //we should use with 3 or 4 values only. Not sure if needs to be enforced though
    assert [range_check_ptr] = values_len - 3;
    let range_check_ptr = range_check_ptr + 1;

    // get most significant chunk
    assert bitwise_ptr[0].x = values[0]; 
    assert bitwise_ptr[0].y = ls_mask;
    assert [results] = bitwise_ptr[0].x_and_y / r_shift;
    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;

    // get middle chunks
    let results = mask_and_shift_inner{
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        ls_mask=ls_mask,
        rs_mask=rs_mask,
        l_shift=l_shift,
        r_shift=r_shift,
    }(values=values, results=results + 1, values_len=values_len, index=0);

    // get least significant chunk
    assert bitwise_ptr[0].x = values[values_len - 2]; 
    assert bitwise_ptr[0].y = rs_mask;
    let left = bitwise_ptr[0].x_and_y * l_shift;
    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;

    let right = values[values_len - 1];
    assert [results] = left + right;

    return ();
}

// Masks and shifts the inner values
func mask_and_shift_inner{
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    ls_mask: felt,
    rs_mask: felt,
    l_shift: felt,
    r_shift: felt,
}(values: felt*, results: felt*, values_len: felt, index: felt) -> felt* {
    if(index + 2 == values_len) {
        return (results);
    }

    assert bitwise_ptr[0].x = values[index]; 
    assert bitwise_ptr[0].y = rs_mask;
    let left = bitwise_ptr[0].x_and_y * l_shift;

    assert bitwise_ptr[1].x = values[index + 1]; 
    assert bitwise_ptr[1].y = ls_mask;
    let right = bitwise_ptr[1].x_and_y / r_shift;

    let bitwise_ptr = bitwise_ptr + 2 * BitwiseBuiltin.SIZE;
    assert [results] = left + right;

    return mask_and_shift_inner(
        values=values,
        results=results + 1,
        values_len=values_len,
        index=index + 1,
    );
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
    let result = le_u64_array_to_be_uint256(
        elements=result_chunks,
        elements_len=result_len,
        bytes_len=result_bytes_len
    );

    return result;
}