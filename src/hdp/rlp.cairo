from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.libs.utils import felt_divmod
from src.libs.rlp_little import extract_byte_at_pos, extract_n_bytes_from_le_64_chunks_array
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, word_reverse_endian

// retrieves an element from an RLP encoded list. The element is selected via its index in the list.
// The validity of RLP is not checked in this function.
// Params:
// - rlp: the rlp encoded state array
// - value_idx: the index of the value to retrieve as index
// - item_starts_at_byte: the byte at which the item starts.
// - counter: the current counter of the recursive function
// Returns: LE 8bytes array of the value + the length of the array
func retrieve_from_rlp_list_via_idx{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(rlp: felt*, value_idx: felt, item_starts_at_byte: felt, counter: felt) -> (
    res: felt*, res_len: felt, bytes_len: felt
) {
    alloc_locals;

    let (item_starts_at_word, item_start_offset) = felt_divmod(item_starts_at_byte, 8);

    let current_item = extract_byte_at_pos(rlp[item_starts_at_word], item_start_offset, pow2_array);

    local item_has_prefix: felt;
    %{
        if ids.current_item < 0x80:
            ids.item_has_prefix = 0
        else:
            ids.item_has_prefix = 1
    %}

    local current_item_len: felt;

    if (item_has_prefix == 1) {
        assert [range_check_ptr] = current_item - 0x80;  // validates item_has_prefix hint
        current_item_len = current_item - 0x80;
        tempvar next_item_starts_at_byte = item_starts_at_byte + current_item_len + 1;
    } else {
        assert [range_check_ptr] = 0x7f - current_item;  // validates item_has_prefix hint
        current_item_len = 1;
        tempvar next_item_starts_at_byte = item_starts_at_byte + current_item_len;
    }

    let range_check_ptr = range_check_ptr + 1;

    if (value_idx == counter) {
        // handle empty bytes case
        if (current_item_len == 0) {
            let (res: felt*) = alloc();
            assert res[0] = 0;
            return (res=res, res_len=1, bytes_len=1);
        }

        // handle prefix case
        if (item_has_prefix == 1) {
            let (word_idx, offset) = felt_divmod(item_starts_at_byte + 1, 8);

            let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
                array=rlp,
                start_word=word_idx,
                start_offset=offset,
                n_bytes=current_item_len,
                pow2_array=pow2_array,
            );

            return (res=res, res_len=res_len, bytes_len=current_item_len);
        } else {
            // handle single byte case
            let (res: felt*) = alloc();
            assert res[0] = current_item;
            return (res=res, res_len=1, bytes_len=1);
        }
    }

    return retrieve_from_rlp_list_via_idx(
        rlp=rlp,
        value_idx=value_idx,
        item_starts_at_byte=next_item_starts_at_byte,
        counter=counter + 1,
    );
}

// decodes an rlp word to a uint256
// Inputs:
// - elements: u64 le chunks containing the rlp word
// - elements_bytes_len: the number of bytes of the elements
// Outputs:
// - the decoded uint256
func decode_rlp_word_to_uint256{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    elements: felt*, elements_bytes_len: felt, to_be: felt
) -> Uint256 {
    alloc_locals;
    // if its a single byte, we can just return it
    if (elements_bytes_len == 1) {
        return (Uint256(low=elements[0], high=0));
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
        elements=result_chunks, elements_len=result_len, bytes_len=result_bytes_len, to_be=to_be
    );

    return result;
}

// Converts a LE 8-bytes chunks to uint256. Converts between [1-4] chunks
// This function should be used for decoding RLP values, as it can deal with arbitrary length values.
// The to_be flag can be used to convert the result to BE.
func le_u64_array_to_uint256{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    elements: felt*, elements_len: felt, bytes_len: felt, to_be: felt
) -> Uint256 {
    alloc_locals;
    local value: Uint256;

    if (elements_len == 1) {
        assert value = Uint256(low=elements[0], high=0);
    }

    if (elements_len == 2) {
        assert value = Uint256(low=elements[1] * pow2_array[64] + elements[0], high=0);
    }

    if (elements_len == 3) {
        assert value = Uint256(low=elements[1] * pow2_array[64] + elements[0], high=elements[2]);
    }

    if (elements_len == 4) {
        assert value = Uint256(
            low=elements[1] * pow2_array[64] + elements[0],
            high=elements[3] * pow2_array[64] + elements[2],
        );
    }

    if (to_be == 1) {
        let flipped = bytewise_endian_flip(value, bytes_len);
        return (flipped);
    } else {
        return (value);
    }
}

// Converts a le uint256 to be. This function can deal with a dynamic number of bytes, ensuring no additional padding is added.
// e.g. 0x1234 -> 0x3412 is a valid output for this function. This is required for reversing the endianess of values derived via RLP decoding.
// In contrast, uint256_reverse_endian: 0x1234 -> 0x34120000000000000000000000000000
func bytewise_endian_flip{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    value: Uint256, bytes_len: felt
) -> Uint256 {
    // value <= 16 bytes
    if (value.high == 0) {
        let (value_low_rev) = word_reverse_endian(value.low);
        let low = value_low_rev / pow2_array[(16 - bytes_len) * 8];

        return (Uint256(low=low, high=0));
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

        return (Uint256(low=low, high=high));
    }
}
