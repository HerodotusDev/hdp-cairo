from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)
from src.utils import reverse_small_chunk_endianess, get_felt_bytes_len, reverse_chunk_endianess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, word_reverse_endian

// retrieves an element from an RLP encoded list. The element is selected via its index in the list.
// The validity of RLP is not checked in this function.
// Params:
// - rlp: the rlp encoded state array
// - field: the index of the value to retrieve
// - item_starts_at_byte: the byte at which the item starts. this skips the RLP list prefix
// - counter: the current counter of the recursive function
// Returns: LE 8bytes array of the value + the length of the array
func retrieve_from_rlp_list_via_idx{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(rlp: felt*, field: felt, item_starts_at_byte: felt, counter: felt) -> (
    res: felt*, res_len: felt, bytes_len: felt
) {
    alloc_locals;

    let (item_starts_at_word, item_start_offset) = felt_divmod(item_starts_at_byte, 8);

    let current_item = extract_byte_at_pos(rlp[item_starts_at_word], item_start_offset, pow2_array);

    local item_type: felt;
    %{
        #print("current item:", hex(ids.current_item))
        if ids.current_item <= 0x7f:
            ids.item_type = 0 # single byte
        elif 0x80 <= ids.current_item <= 0xb6:
            ids.item_type = 1 # short string
        elif 0xb7 <= ids.current_item <= 0xbf:
            ids.item_type = 2 # long string
        elif 0xc0 <= ids.current_item <= 0xf6:
            ids.item_type = 3 # short list
        elif 0xf7 <= ids.current_item <= 0xff:
            ids.item_type = 4 # long list
        else:
            assert False, "Invalid RLP item"
    %}

    local current_value_len: felt;
    local current_value_starts_at_byte: felt;
    local next_item_starts_at_byte: felt;

    // Single Byte
    if (item_type == 0) {
        assert [range_check_ptr] = 0x7f - current_item;
        assert current_value_len = 1;
        assert current_value_starts_at_byte = item_starts_at_byte;
        assert next_item_starts_at_byte = current_value_starts_at_byte + current_value_len;
        tempvar range_check_ptr = range_check_ptr + 1;
    } else {
        tempvar range_check_ptr = range_check_ptr;
    }

    // Short String
    if (item_type == 1) {
        assert [range_check_ptr] = current_item - 0x80;
        assert [range_check_ptr + 1] = 0xb6 - current_item;
        assert current_value_len = current_item - 0x80;
        assert current_value_starts_at_byte = item_starts_at_byte + 1;
        assert next_item_starts_at_byte = current_value_starts_at_byte + current_value_len;

        tempvar range_check_ptr = range_check_ptr + 2;
    } else {
        tempvar range_check_ptr = range_check_ptr;
    }

    // Long String
    if (item_type == 2) {
        assert [range_check_ptr] = current_item - 0xb7;
        assert [range_check_ptr + 1] = 0xbf - current_item;
        tempvar range_check_ptr = range_check_ptr + 2;
        let len_len = current_item - 0xb7;

        let value_len = decode_value_len(
            rlp=rlp, item_starts_at_byte=item_starts_at_byte, len_len=len_len, pow2_array=pow2_array
        );

        assert current_value_len = value_len;
        assert current_value_starts_at_byte = item_starts_at_byte + len_len + 1;
        assert next_item_starts_at_byte = current_value_starts_at_byte + current_value_len;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
    }

    // Short List
    if (item_type == 3) {
        assert [range_check_ptr] = current_item - 0xc0;
        assert [range_check_ptr + 1] = 0xf6 - current_item;
        assert current_value_len = current_item - 0xc0;
        assert current_value_starts_at_byte = item_starts_at_byte + 1;
        assert next_item_starts_at_byte = current_value_starts_at_byte + current_value_len;

        tempvar range_check_ptr = range_check_ptr + 2;
    } else {
        tempvar range_check_ptr = range_check_ptr;
    }

    // Long List
    if (item_type == 4) {
        assert [range_check_ptr] = current_item - 0xf7;
        assert [range_check_ptr + 1] = 0xff - current_item;
        tempvar range_check_ptr = range_check_ptr + 2;
        let len_len = current_item - 0xf7;
        let item_len = decode_value_len(
            rlp=rlp, item_starts_at_byte=item_starts_at_byte, len_len=len_len, pow2_array=pow2_array
        );

        assert current_value_len = item_len;
        assert current_value_starts_at_byte = item_starts_at_byte + len_len + 1;
        assert next_item_starts_at_byte = current_value_starts_at_byte + current_value_len;

        tempvar range_check_ptr = range_check_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
    }

    if (field == counter) {
        if (current_value_len == 0) {
            let (res: felt*) = alloc();
            assert res[0] = 0;
            return (res=res, res_len=1, bytes_len=1);
        } else {
            let (word, offset) = felt_divmod(current_value_starts_at_byte, 8);
            let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
                array=rlp,
                start_word=word,
                start_offset=offset,
                n_bytes=current_value_len,
                pow2_array=pow2_array,
            );
            return (res=res, res_len=res_len, bytes_len=current_value_len);
        }
    } else {
        return retrieve_from_rlp_list_via_idx(
            rlp=rlp, field=field, item_starts_at_byte=next_item_starts_at_byte, counter=counter + 1
        );
    }
}

// decodes the length prefix of an RLP value. This is used for long strings and lists.
// A prefix larger then 56bits will cause the function to fail. Should be sufficient for the current use case.
func decode_value_len{range_check_ptr}(
    rlp: felt*, item_starts_at_byte: felt, len_len: felt, pow2_array: felt*
) -> felt {
    let (word, offset) = felt_divmod(item_starts_at_byte + 1, 8);

    let (current_value_len_list, _) = extract_n_bytes_from_le_64_chunks_array(
        array=rlp, start_word=word, start_offset=offset, n_bytes=len_len, pow2_array=pow2_array
    );

    return reverse_small_chunk_endianess(current_value_len_list[0], len_len);
}

// Decodes a LE RLP string (<= 8 bytes) to a felt
// Inputs:
// - value: the LE RLP value
// Outputs:
// - the decoded felt in BE
func decode_le_rlp_string_small{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(value: felt) -> felt {
    alloc_locals;

    let bytes_len = get_felt_bytes_len(value);

    if(bytes_len == 1) {
        if(value == 0x80) {
            return 0;
        } else {
            return value;
        }
    }

    let (q, r) = felt_divmod(value, 0x100); // remove trailing byte

    // ensure we have a short string
    assert [range_check_ptr] = 8 - bytes_len;
    assert [range_check_ptr + 1] = r - 0x80;
    assert [range_check_ptr + 2] = 0xb6 - r;
    tempvar range_check_ptr = range_check_ptr + 3;

    let result = reverse_chunk_endianess(q, bytes_len - 1);
    return (result);
}

// decodes an rlp word to a uint256
// Inputs:
// - elements: u64 le chunks containing the rlp word
// - elements_bytes_len: the number of bytes of the elements
// Outputs:
// - the decoded uint256
func decode_rlp_word_to_uint256{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    elements: felt*, elements_bytes_len: felt
) -> Uint256 {
    alloc_locals;
    // if its a single byte, we can just return it
    if (elements_bytes_len == 1) {
        return (Uint256(low=0, high=elements[0] * pow2_array[120]));
    }

    // fetch length from rlp prefix
    let prefix = extract_byte_at_pos{bitwise_ptr=bitwise_ptr}(elements[0], 0, pow2_array);
    local result_bytes_len = prefix - 0x80;  // works since word has max. 32 bytes

    let (result_chunks, result_len) = extract_n_bytes_from_le_64_chunks_array(
        array=elements,
        start_word=0,
        start_offset=1,
        n_bytes=result_bytes_len,
        pow2_array=pow2_array,
    );

    // convert to uint256
    let result = le_u64_array_to_uint256(
        elements=result_chunks, elements_len=result_len, bytes_len=result_bytes_len
    );

    return result;
}

// Converts a LE 8-bytes chunks to uint256. Converts between [1-4] chunks
// This function should be used for decoding RLP values, as it can deal with arbitrary length values.
// The to_be flag can be used to convert the result to BE.
func le_u64_array_to_uint256{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    elements: felt*, elements_len: felt, bytes_len: felt
) -> Uint256 {
    alloc_locals;
    local value: Uint256;

    if (elements_len == 1) {
        let high = elements[0] * pow2_array[(16 - bytes_len) * 8];
        assert value = Uint256(low=0, high=high);
    }

    if (elements_len == 2) {
        assert value = Uint256(
            low=0,
            high=(elements[1] * pow2_array[64] + elements[0]) * pow2_array[(16 - bytes_len) * 8],
        );
    }

    // For values larger then 16 bytes, we need to shift the chunks to the left.
    let (_, local offset) = felt_divmod(bytes_len, 8);  // calculate the offset from the bytes_len
    let (le_shifted) = shift_for_le_uint256(elements, elements_len, offset);

    // tempvar range_check_ptr = range_check_ptr;
    if (elements_len == 3) {
        assert value = Uint256(
            low=le_shifted[0] * pow2_array[64], high=le_shifted[2] * pow2_array[64] + le_shifted[1]
        );
    }

    if (elements_len == 4) {
        assert value = Uint256(
            low=le_shifted[1] * pow2_array[64] + le_shifted[0],
            high=le_shifted[3] * pow2_array[64] + le_shifted[2],
        );
    }

    return (value);
}

func shift_for_le_uint256{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    value: felt*, value_len: felt, offset: felt
) -> (shifted: felt*) {
    alloc_locals;
    let (local result: felt*) = alloc();

    if (offset == 0) {
        return (shifted=value);
    }

    let devisor = pow2_array[offset * 8];
    let shifter = pow2_array[(8 - offset) * 8];

    tempvar current_word = 0;
    tempvar n_processed_words = 0;
    tempvar i = 0;

    loop:
    let i = [ap - 1];
    let n_processed_words = [ap - 2];
    let current_word = [ap - 3];

    %{ memory[ap] = 1 if (ids.value_len - ids.n_processed_words == 0) else 0 %}
    jmp end_loop if [ap] != 0, ap++;

    // Inlined felt_divmod (unsigned_div_rem).
    let q = [ap];
    let r = [ap + 1];
    %{
        ids.q, ids.r = divmod(memory[ids.value + ids.i], ids.devisor)
        #print(f"val={memory[ids.value + ids.i]} q={ids.q} r={ids.r} i={ids.i}")
    %}
    ap += 2;
    tempvar offset = 3 * n_processed_words;
    assert [range_check_ptr + offset] = q;
    assert [range_check_ptr + offset + 1] = r;
    assert [range_check_ptr + offset + 2] = devisor - r - 1;
    assert q * devisor + r = value[i];
    // done inlining felt_divmod.

    assert result[n_processed_words] = current_word + r * shifter;
    [ap] = q, ap++;
    [ap] = n_processed_words + 1, ap++;
    [ap] = i + 1, ap++;

    jmp loop;

    end_loop:
    assert value_len = n_processed_words;
    tempvar range_check_ptr = range_check_ptr + 3 * n_processed_words;
    assert current_word = 0;

    return (shifted=result);
}
