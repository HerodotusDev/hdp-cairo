from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem as felt_divmod
from starkware.cairo.common.alloc import alloc

// Takes a 64 bit word in little endian, returns the byte at a given position as it would be in big endian.
// Ie: word = b7 b6 b5 b4 b3 b2 b1 b0
// returns bi such that i = byte_position
func extract_byte_at_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, byte_position: felt, pow2_array: felt*
) -> felt {
    assert bitwise_ptr.x = word_64_little;
    assert bitwise_ptr.y = 0xff * pow2_array[8 * byte_position];
    let extracted_byte_at_pos = bitwise_ptr.x_and_y / pow2_array[8 * byte_position];
    tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return extracted_byte_at_pos;
}

// Takes a 64 bit word with little endian bytes, returns the nibble at a given position as it would be in big endian.
// Input of the form: word_64_bits = n14 n15 n12 n13 n10 n11 n8 n9 n6 n7 n4 n5 n2 n3 n0 n1
// returns ni such that i = 2 * byte_position + 1 if first_nibble != 0
// returns ni such that i = 2 * byte_position if first_nibble = 0
func extract_nibble_at_byte_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, byte_pos: felt, first_nibble: felt, pow2_array: felt*
) -> felt {
    if (first_nibble == 0) {
        tempvar offset = pow2_array[8 * byte_pos + 4];
        assert bitwise_ptr.x = word_64_little;
        assert bitwise_ptr.y = 0xf * offset;
        let extracted_nibble_at_pos = bitwise_ptr.x_and_y / offset;
        tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return extracted_nibble_at_pos;
    } else {
        tempvar offset = pow2_array[8 * byte_pos];
        assert bitwise_ptr.x = word_64_little;
        assert bitwise_ptr.y = 0xf * pow2_array[offset];
        let extracted_nibble_at_pos = bitwise_ptr.x_and_y / offset;
        tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return extracted_nibble_at_pos;
    }
}

// Takes a 64 bit word in little endian, returns the byte at a given position as it would be in big endian.
// Ie: word = b7 b6 b5 b4 b3 b2 b1 b0
// returns [b(i+n-1) ... b(i+1) bi] such that i = pos and n = n.
// Doesn't check if 0 <= pos <= 7 and pos + n <= 7
// Returns 0 if n=0.
func extract_n_bytes_at_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, pos: felt, n: felt, pow2_array: felt*
) -> felt {
    %{ print(f"extracting {ids.n} bytes at pos {ids.pos} from {hex(ids.word_64_little)}") %}
    let x_mask = get_0xff_mask(n);
    %{ print(f"x_mask for len {ids.n}: {hex(ids.x_mask)}") %}
    assert bitwise_ptr[0].x = word_64_little;
    assert bitwise_ptr[0].y = x_mask * pow2_array[8 * (pos)];
    tempvar res = bitwise_ptr[0].x_and_y;
    %{ print(f"tmp : {hex(ids.res)}") %}
    tempvar extracted_bytes = bitwise_ptr[0].x_and_y / pow2_array[8 * pos];
    tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return extracted_bytes;
}

func extract_le_hash_from_le_64_chunks_array{range_check_ptr}(
    array: felt*, start_word: felt, start_offset: felt, pow2_array: felt*
) -> (extracted_hash: Uint256) {
    alloc_locals;
    tempvar pow = pow2_array[8 * start_offset];
    tempvar pow_0 = pow2_array[64 - 8 * start_offset];
    tempvar pow_1 = 2 ** 64 * pow_0;
    let (arr_0, _) = felt_divmod(array[start_word], pow);
    let arr_1 = array[start_word + 1];
    let (arr_2_left, arr_2_right) = felt_divmod(array[start_word + 2], pow);
    let arr_3 = array[start_word + 3];
    let (_, arr_4) = felt_divmod(array[start_word + 4], pow);

    let res_low = arr_2_right * pow_1 + arr_1 * pow_0 + arr_0;
    let res_high = arr_4 * pow_1 + arr_3 * pow_0 + arr_2_left;

    let res = Uint256(low=res_low, high=res_high);
    return (res,);
}

// From an array of 64 bit words in little endian, extract n bytes starting at start_word and start_offset.
// array is of the form [b7 b6 b5 b4 b3 b2 b1 b0, b15 b14 b13 b12 b11 b10 b9 b8, ...]
// start_word is the index of the first word to extract from (starting from 0)
// start_offset is the offset in bytes from the start of the word (in [[0, 7]])
// returns an array of the form [c7 c6 c5 c4 c3 c2 c1 c0, c15 c14 c13 c12 c11 c10 c9 c8, ..., cn-1 cn-2 ...]
// (last word might be less than 8 bytes),
// such that ci = b_(8*start_word + start_offset + i)
func extract_n_bytes_from_le_64_chunks_array{range_check_ptr}(
    array: felt*, start_word: felt, start_offset: felt, n_bytes: felt, pow2_array: felt*
) -> (extracted_bytes: felt*, n_words: felt) {
    alloc_locals;
    let (local res: felt*) = alloc();

    let (q, n_ending_bytes) = felt_divmod(n_bytes, 8);

    local n_words: felt;

    if (q == 0) {
        if (n_ending_bytes == 0) {
            // 0 bytes to extract, forbidden.
            assert 1 = 0;
        } else {
            // 1 to 7 bytes to extract.
            assert n_words = 1;
        }
    } else {
        if (n_ending_bytes == 0) {
            assert n_words = q;
        } else {
            assert n_words = q + 1;
        }
    }

    // %{
    //     print(f"Start word: {ids.start_word}, start_offset: {ids.start_offset}, n_bytes: {ids.n_bytes}")
    //     print(f"n_words={ids.n_words} n_ending_bytes={ids.n_ending_bytes} \n")
    // %}

    // Handle trivial case where start_offset = 0., words can be copied directly.
    if (start_offset == 0) {
        // %{ print(f"copying {ids.q} words... ") %}
        array_copy(src=array + start_word, dst=res, n=q, index=0);
        if (n_ending_bytes != 0) {
            let (_, last_word) = felt_divmod(array[start_word + q], pow2_array[8 * n_ending_bytes]);
            assert res[q] = last_word;
            return (res, n_words);
        }
        return (res, n_words);
    }

    local pow_cut = pow2_array[8 * start_offset];
    local pow_acc = pow2_array[64 - 8 * start_offset];

    let (current_word, _) = felt_divmod(array[start_word], pow_cut);

    if (n_words == 1) {
        local needs_next_word: felt;
        local avl_bytes_in_first_word = 8 - start_offset;
        %{ ids.needs_next_word = 1 if ids.n_bytes > ids.avl_bytes_in_first_word else 0 %}
        if (needs_next_word == 0) {
            // %{ print(f"current_word={hex(ids.current_word)}") %}
            let (_, last_word) = felt_divmod(current_word, pow2_array[8 * n_ending_bytes]);
            assert res[0] = last_word;
            return (res, 1);
        } else {
            // %{ print(f"needs next word, avl_bytes_in_first_word={ids.avl_bytes_in_first_word}") %}
            // %{ print(f"current_word={hex(ids.current_word)}") %}

            let (_, last_word) = felt_divmod(
                array[start_word + 1], pow2_array[8 * (n_bytes - 8 + start_offset)]
            );
            assert res[0] = current_word + last_word * pow_acc;
            return (res, 1);
        }
    }

    // %{
    //     from math import log2
    //     print(f"pow_acc = 2**{log2(ids.pow_acc)}, pow_cut = 2**{log2(ids.pow_cut)}")
    // %}
    local range_check_ptr = range_check_ptr;
    local n_words_to_handle_in_loop;

    if (n_ending_bytes != 0) {
        assert n_words_to_handle_in_loop = n_words - 1;
    } else {
        assert n_words_to_handle_in_loop = n_words;
    }

    tempvar current_word = current_word;
    tempvar n_words_handled = 0;
    tempvar i = 1;

    cut_loop:
    let i = [ap - 1];
    let n_words_handled = [ap - 2];
    let current_word = [ap - 3];
    // %{ print(f"enter loop : {ids.i} {ids.n_words_handled}/{ids.n_words}") %}
    %{ memory[ap] = 1 if (ids.n_words_to_handle_in_loop - ids.n_words_handled) == 0 else 0 %}
    jmp end_loop if [ap] != 0, ap++;

    // Inlined felt_divmod (unsigned_div_rem).
    let q = [ap];
    let r = [ap + 1];
    %{
        ids.q, ids.r = divmod(memory[ids.array + ids.start_word + ids.i], ids.pow_cut)
        #print(f"val={memory[ids.array + ids.start_word + ids.i]} q={ids.q} r={ids.r}")
    %}
    ap += 2;
    tempvar offset = 3 * n_words_handled;
    assert [range_check_ptr + offset] = q;
    assert [range_check_ptr + offset + 1] = r;
    assert [range_check_ptr + offset + 2] = pow_cut - r - 1;
    assert q * pow_cut + r = array[start_word + i];
    // done inlining felt_divmod.

    assert res[n_words_handled] = current_word + r * pow_acc;
    // %{ print(f"new word : {memory[ids.res + ids.n_words_handled]}") %}
    [ap] = q, ap++;
    [ap] = n_words_handled + 1, ap++;
    [ap] = i + 1, ap++;
    jmp cut_loop;

    end_loop:
    assert n_words_to_handle_in_loop - n_words_handled = 0;
    tempvar range_check_ptr = range_check_ptr + 3 * n_words_handled;

    if (n_ending_bytes != 0) {
        // %{ print(f"handling last word...") %}
        let (current_word, _) = felt_divmod(array[start_word + n_words_handled], pow_cut);
        local needs_next_word: felt;
        local avl_bytes_in_word = 8 - start_offset;
        %{ ids.needs_next_word = 1 if ids.n_ending_bytes > ids.avl_bytes_in_word else 0 %}
        if (needs_next_word == 0) {
            let (_, last_word) = felt_divmod(current_word, pow2_array[8 * n_ending_bytes]);
            assert res[n_words_handled] = last_word;
            return (res, n_words);
        } else {
            let (_, last_word) = felt_divmod(
                array[start_word + n_words_handled + 1],
                pow2_array[8 * (n_ending_bytes - 8 + start_offset)],
            );
            assert res[n_words_handled] = current_word + last_word * pow_acc;
            return (res, n_words);
        }
    }

    return (res, n_words_handled);
}

// func extract_n_bytes_from_le_64_chunks_array_inner(array:felt*, current_word:felt, n_words_handled:felt,

func array_copy(src: felt*, dst: felt*, n: felt, index: felt) {
    if (index == n) {
        return ();
    } else {
        assert dst[index] = src[index];
        return array_copy(src=src, dst=dst, n=n, index=index + 1);
    }
}

n_0xff:
dw 0;
dw 0xff;
dw 0xffff;
dw 0xffffff;
dw 0xffffffff;
dw 0xffffffffff;
dw 0xffffffffffff;
dw 0xffffffffffffff;
dw 0xffffffffffffffff;

func get_0xff_mask(n: felt) -> felt {
    let (_, pc) = get_fp_and_pc();

    pc_labelx:
    let data = pc + (n_0xff - pc_labelx);

    let res = [data + n];

    return res;
}
