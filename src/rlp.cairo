from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)
from src.utils import reverse_small_chunk_endianess, get_felt_bytes_len, reverse_chunk_endianess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, word_reverse_endian
from packages.eth_essentials.lib.rlp_little import array_copy

// Returns the index of the first list element, and the list length in bytes.
// This function can be used to derive the item_starts_at_byte param for rlp_list_retrieve.
// Params:
// - rlp: an RLP encoded list (long or short)
// func rlp_get_list_meta{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*} (
//     rlp: felt*
// ) -> (value_start: felt, bytes_len: felt) {
//     let first_byte = extract_byte_at_pos(rlp[item_starts_at_word], item_start_offset, pow2_array);

//     local is_long: felt;
//     %{
//         if 0xc0 <= ids.first_byte <= 0xf6:
//             ids.is_long = 0 # short list
//         elif 0xf7 <= ids.first_byte <= 0xff:
//             ids.is_long = 1 # long list
//         else:
//             assert False, "Invalid RLP list"
//     %}


//     local value_start: felt;
//     local bytes_len: felt;
//     if (is_long == 0) {
//         assert [range_check_ptr] = first_byte - 0xc0;
//         assert [range_check_ptr + 1] = 0xf6 - first_byte;
//         assert bytes_len = first_byte - 0xc0;
//         assert value_start = 1;

//         tempvar range_check_ptr = range_check_ptr + 2;
//     } else {
//         assert [range_check_ptr] = first_byte - 0xf7;
//         assert [range_check_ptr + 1] = 0xff - first_byte;
//         tempvar range_check_ptr = range_check_ptr + 2;

//         let len_len = first_byte - 0xf7;
//         let bytes_len = decode_long_value_len(
//             rlp=rlp, item_starts_at_byte=item_starts_at_byte + 1, len_len=len_len, pow2_array=pow2_array
//         );
//         assert value_start = 1 + len_len;
//     }

//     return (value_start=value_start, bytes_len=bytes_len);
// }

// retrieves an element from an RLP encoded list (LE chunks). The element is selected via its index in the list.
// The passed rlp chunks should not contain the RLP list prefix, only the elements.
// Params:
// - rlp: the rlp encoded (LE chunks) state array
// - field: the index of the value to retrieve
// - item_starts_at_byte: the byte at which the item starts. this skips the RLP list prefix
// - counter: the current counter of the recursive function
// Returns: LE 8bytes array of the value + the length of the array
func rlp_list_retrieve{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    rlp: felt*, field: felt, item_starts_at_byte: felt, counter: felt
) -> (res: felt*, res_len: felt, bytes_len: felt) {
    alloc_locals;


    let (item_starts_at_word, item_start_offset) = felt_divmod(item_starts_at_byte, 8);
    // %{
    //     print("item_starts_at_word:", ids.item_starts_at_word)
    //     print("item_start_offset:", ids.item_start_offset)
    //     print("item_starts_at_byte:", ids.item_starts_at_byte)
    //     print ("rlp0:", hex(memory[ids.rlp]))
    // %}

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

        let value_len = decode_long_value_len(
            rlp=rlp, item_starts_at_byte=item_starts_at_byte + 1, len_len=len_len, pow2_array=pow2_array
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
        let item_len = decode_long_value_len(
            rlp=rlp, item_starts_at_byte=item_starts_at_byte + 1, len_len=len_len, pow2_array=pow2_array
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
        return rlp_list_retrieve(
            rlp=rlp, field=field, item_starts_at_byte=next_item_starts_at_byte, counter=counter + 1
        );
    }
}

// decodes the length prefix of an RLP value. This is used for long strings and long lists.
// A prefix larger then 56bits will cause the function to fail. Should be sufficient for the current use case.
func decode_long_value_len{range_check_ptr}(
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
func chunk_to_felt_be{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    value: felt
) -> felt {
    alloc_locals;

    let bytes_len = get_felt_bytes_len(value);

    if (bytes_len == 1) {
        if (value == 0x80) {
            return 0;
        } else {
            return value;
        }
    }

    let (q, r) = felt_divmod(value, 0x100);  // remove trailing byte

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
    rlp: felt*
) -> Uint256 {
    alloc_locals;

    let (value, value_len, value_bytes_len) = rlp_list_retrieve(
        rlp=rlp, field=0, item_starts_at_byte=0, counter=0
    );

    // convert to uint256
    let result = le_chunks_to_uint256(
        elements=value, elements_len=value_len, bytes_len=value_bytes_len
    );

    return result;
}

// Converts a LE 8-bytes chunks to uint256. Converts between [1-4] chunks
// This function should be used for decoding RLP values, as it can deal with arbitrary length values.
// Inputs:
// - elements: the LE 8-bytes chunks
// - elements_len: the number of chunks
// - bytes_len: the number of bytes of the elements
// Outputs:
// - the decoded uint256 in LE
func le_chunks_to_uint256{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
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
    let (le_shifted) = right_shift_le_chunks(elements, elements_len, offset);

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

// This function is required when constructing a LE uint256 from LE chunks.
// In BE, the function shifts elements to the right:
//  e.g. [0x1122334455667788, 0x11] -> [0x11, 0x2233445566778811]
// This function does the same thing, but on LE chunks. This results in the following:
// e.g. [0x1122334455667788, 0x11] -> [0x8800000000000000, 0x1111223344556677]
// Inputs:
// - value: the LE chunks
// - value_len: the number of chunks
// - offset: the number of bytes to shift
// Outputs:
// - the shifted LE chunks
func right_shift_le_chunks{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    value: felt*, value_len: felt, offset: felt
) -> (shifted: felt*) {
    alloc_locals;
    let (local result: felt*) = alloc();

    if (offset == 0) {
        return (shifted=value);
    }

    assert [range_check_ptr] = 7 - offset;
    assert [range_check_ptr + 1] = value_len - 1;
    let range_check_ptr = range_check_ptr + 2;

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

// Prepends a LE encoded item to an RLP list.
// Inputs:
// - item_bytes_len: the number of bytes in the item.
// - item: the item to prepend (max 64 bits).
// - rlp: the RLP list.
// - rlp_len: the length of the RLP list.
// - expected_bytes_len: the expected number of bytes in the RLP list after prepending the item.
// Outputs:
// - encoded: the new RLP list.
// - encoded_len: the length of the new RLP list.
func prepend_le_chunks{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    item_bytes_len: felt, item: felt, rlp: felt*, rlp_len: felt, expected_bytes_len: felt
) -> (encoded: felt*, encoded_len: felt) {
    // we have no item_bytes_len if the prefix is 0
    if (item_bytes_len == 0) {
        return (encoded=rlp, encoded_len=rlp_len);
    }

    alloc_locals;

    assert [range_check_ptr] = 8 - item_bytes_len;
    let range_check_ptr = range_check_ptr + 1;

    let (local result: felt*) = alloc();

    let shifter = pow2_array[item_bytes_len * 8];
    let devisor = pow2_array[(8 - item_bytes_len) * 8];

    tempvar current_word = item;
    tempvar n_processed_words = 0;
    tempvar i = 0;

    loop:
    let i = [ap - 1];
    let n_processed_words = [ap - 2];
    let current_word = [ap - 3];

    %{ memory[ap] = 1 if (ids.rlp_len - ids.n_processed_words == 0) else 0 %}
    jmp end_loop if [ap] != 0, ap++;

    // Inlined felt_divmod (unsigned_div_rem).
    let q = [ap];
    let r = [ap + 1];
    %{
        ids.q, ids.r = divmod(memory[ids.rlp + ids.i], ids.devisor)
        #print(f"val={hex(memory[ids.rlp + ids.i])} q/cur={hex(ids.q)} r={hex(ids.r)} i={ids.i}")
    %}
    ap += 2;
    tempvar item_bytes_len = 3 * n_processed_words;
    assert [range_check_ptr + item_bytes_len] = q;
    assert [range_check_ptr + item_bytes_len + 1] = r;
    assert [range_check_ptr + item_bytes_len + 2] = devisor - r - 1;
    assert q * devisor + r = rlp[i];
    // done inlining felt_divmod.

    assert result[n_processed_words] = current_word + r * shifter;
    [ap] = q, ap++;
    [ap] = n_processed_words + 1, ap++;
    [ap] = i + 1, ap++;

    jmp loop;

    end_loop:
    assert rlp_len = n_processed_words;
    tempvar range_check_ptr = range_check_ptr + 3 * n_processed_words;

    let (words, rest) = felt_divmod(expected_bytes_len, 8);
    if (rest == 0) {
        return (encoded=result, encoded_len=rlp_len);
    } else {
        // since rest > 0, we expect word + 1 words to be done
        if (words + 1 == n_processed_words) {
            return (encoded=result, encoded_len=rlp_len);
        } else {
            // add the remaining word
            assert result[n_processed_words] = current_word;
            return (encoded=result, encoded_len=rlp_len + 1);
        }
    }
}

// Reverses the endianness of a chunk and appends it to a list of chunks and returns new list
// Inputs:
// - list: the le chunks list to append to
// - list_bytes_len: the length of the list in bytes
// - item: the BE chunk to append (max 8 bytes)
// - item_bytes_len: the length of the item in bytes
// Outputs:
// - list: the new list
// - list_len: the length of the new list
// - list_bytes_len: the length of the new list in bytes
func append_be_chunk{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    list: felt*, list_bytes_len: felt, chunk: felt, chunk_bytes_len: felt
) -> (list: felt*, list_len: felt, list_bytes_len: felt) {
    alloc_locals;

    assert [range_check_ptr] = 8 - chunk_bytes_len;
    tempvar range_check_ptr = range_check_ptr + 1;

    let (word, offset) = felt_divmod(list_bytes_len, 8);
    let le_chunk = reverse_chunk_endianess{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr
    }(chunk, chunk_bytes_len);

    if (offset == 0) {
        assert list[word] = le_chunk;
        return (list=list, list_len=word + 1, list_bytes_len=list_bytes_len + chunk_bytes_len);
    }

    // copy every element except the last one
    let (result) = alloc();
    array_copy(list, result, word, 0);

    // reverse and extend the chunk
    let le_extended = le_chunk * pow2_array[offset * 8];

    let (new_item, msb_item) = felt_divmod(le_extended, pow2_array[64]);
    assert result[word] = msb_item + list[word];

    if (new_item != 0) {
        assert result[word + 1] = new_item;
        return (list=result, list_len=word + 2, list_bytes_len=list_bytes_len + chunk_bytes_len);
    } else {
        return (list=result, list_len=word + 1, list_bytes_len=list_bytes_len + chunk_bytes_len);
    }
}
