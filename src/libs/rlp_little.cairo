from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256, uint256_pow2, uint256_unsigned_div_rem
from starkware.cairo.common.alloc import alloc
from src.libs.utils import felt_divmod_8, felt_divmod, get_0xff_mask, word_reverse_endian_64

// Takes a 64 bit word in little endian, returns the byte at a given position as it would be in big endian.
// Ie: word = b7 b6 b5 b4 b3 b2 b1 b0
// returns bi such that i = byte_position
func extract_byte_at_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, byte_position: felt, pow2_array: felt*
) -> felt {
    tempvar pow = pow2_array[8 * byte_position];
    assert bitwise_ptr.x = word_64_little;
    assert bitwise_ptr.y = 0xff * pow;
    let extracted_byte_at_pos = bitwise_ptr.x_and_y / pow;
    tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return extracted_byte_at_pos;
}

// Takes a 64 bit word with little endian bytes, returns the nibble at a given position as it would be in big endian.
// Input of the form: word_64_bits = n14 n15 n12 n13 n10 n11 n8 n9 n6 n7 n4 n5 n2 n3 n0 n1
// returns ni such that :
// i = 2 * byte_position if nibble_pos = 0
// i = 2 * byte_position + 1 if nibble_pos != 0
// nibble_pos is the position within the byte, first nibble of the byte is 0, second is 1 (here 1 <=> !=0 to avoid a range check).
func extract_nibble_at_byte_pos{bitwise_ptr: BitwiseBuiltin*}(
    word_64_little: felt, byte_pos: felt, nibble_pos: felt, pow2_array: felt*
) -> felt {
    if (nibble_pos == 0) {
        tempvar pow = pow2_array[8 * byte_pos + 4];
        assert bitwise_ptr.x = word_64_little;
        assert bitwise_ptr.y = 0xf * pow;
        let extracted_nibble_at_pos = bitwise_ptr.x_and_y / pow;
        tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return extracted_nibble_at_pos;
    } else {
        tempvar pow = pow2_array[8 * byte_pos];
        assert bitwise_ptr.x = word_64_little;
        assert bitwise_ptr.y = 0xf * pow;
        let extracted_nibble_at_pos = bitwise_ptr.x_and_y / pow;
        tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
        return extracted_nibble_at_pos;
    }
}

func key_subset_to_uint256(key_subset: felt*, key_subset_len: felt) -> Uint256 {
    if (key_subset_len == 1) {
        let res = Uint256(low=key_subset[0], high=0);
        return res;
    }
    if (key_subset_len == 2) {
        let res = Uint256(low=key_subset[0] + key_subset[1] * 2 ** 64, high=0);
        return res;
    }
    if (key_subset_len == 3) {
        let res = Uint256(low=key_subset[0] + key_subset[1] * 2 ** 64, high=key_subset[2]);
        return res;
    }
    if (key_subset_len == 4) {
        let res = Uint256(
            low=key_subset[0] + key_subset[1] * 2 ** 64,
            high=key_subset[2] + key_subset[3] * 2 ** 64,
        );
        return res;
    }
    assert 1 = 0;
    // Should never happen, key is at most 256 bits (4x64 bits words).
    let res = Uint256(low=0, high=0);
    return res;
}
// params:
// key_subset : array of 64 bit words with little endian bytes, representing a subset of the key
// key_subset_len : length of the subset in number of 64 bit words
// key_subset_bytes_len : length of the subset in number of bytes
// key subset is of the form [b7 b6 b5 b4 b3 b2 b1 b0, b15 b14 b13 b12 b11 b10 b9 b8, ...]
// key_little : 256 bit key in little endian
// key_little is of the form high = [b63, ..., b32] , low = [b31, ..., b0]
func assert_subset_in_key{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    key_subset: felt*,
    key_subset_len: felt,
    key_subset_nibble_len: felt,
    key_little: Uint256,
    n_nibbles_already_checked: felt,
    cut_nibble: felt,
    pow2_array: felt*,
) -> () {
    alloc_locals;
    let key_subset_256t = key_subset_to_uint256(key_subset, key_subset_len);
    %{ print(f"key_susbet_uncut={hex(ids.key_subset_256t.low + ids.key_subset_256t.high*2**128)}") %}

    local key_subset_256: Uint256;
    local key_subset_last_nibble: felt;

    let (_, odd_checked_nibbles) = felt_divmod(n_nibbles_already_checked, 2);

    if (cut_nibble != 0) {
        %{ print(f"Cut nibble") %}
        let (key_subset_256ltmp, byte) = felt_divmod(key_subset_256t.low, 2 ** 8);
        let (key_subset_256h, acc) = felt_divmod(key_subset_256t.high, 2 ** 8);
        let (_, nibble) = felt_divmod(byte, 2 ** 4);
        assert key_subset_256.low = key_subset_256ltmp + acc * 2 ** (128 - 8);
        assert key_subset_256.high = key_subset_256h;
        assert key_subset_last_nibble = nibble;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        assert key_subset_256.low = key_subset_256t.low;
        assert key_subset_256.high = key_subset_256t.high;
        assert key_subset_last_nibble = 0;
        tempvar range_check_ptr = range_check_ptr;
    }
    %{ print(f"key_susbet_cutted={hex(ids.key_subset_256.low + ids.key_subset_256.high*2**128)}") %}
    %{ print(f"key_little={hex(ids.key_little.low + ids.key_little.high*2**128)}") %}

    local key_shifted: Uint256;
    local key_shifted_last_nibble: felt;
    if (odd_checked_nibbles != 0) {
        let (upow) = uint256_pow2(Uint256((n_nibbles_already_checked + 1) * 4, 0));
        let (key_shiftedt, rem) = uint256_unsigned_div_rem(key_little, upow);
        let (upow_) = uint256_pow2(Uint256((n_nibbles_already_checked - 1) * 4, 0));
        let (byte_u256, _) = uint256_unsigned_div_rem(rem, upow_);
        let (_, nibble) = felt_divmod(byte_u256.low, 2 ** 4);
        assert key_shifted.low = key_shiftedt.low;
        assert key_shifted.high = key_shiftedt.high;
        assert key_shifted_last_nibble = nibble;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        let (upow) = uint256_pow2(Uint256(n_nibbles_already_checked * 4, 0));
        let (key_shiftedt, _) = uint256_unsigned_div_rem(key_little, upow);
        assert key_shifted.low = key_shiftedt.low;
        assert key_shifted.high = key_shiftedt.high;
        assert key_shifted_last_nibble = 0;
        tempvar range_check_ptr = range_check_ptr;
    }

    %{ print(f"key_shifted={hex(ids.key_shifted.low + ids.key_shifted.high*2**128)}") %}

    if (key_subset_256.high != 0) {
        // caution : high part must have less or equal 30 nibbles. for felt divmod.
        let n_nibble_in_high_part = key_subset_nibble_len - 32;

        let (_, key_high) = felt_divmod(key_shifted.high, pow2_array[4 * n_nibble_in_high_part]);
        %{
            print(f"\t N nibbles in right part : {ids.n_nibble_in_high_part}") 
            print(f"\t orig key high : {hex(ids.key_little.high)}")
            print(f"\t key shifted high : {hex(ids.key_shifted.high)}")
            print(f"\t final key high : {hex(ids.key_high)}")
            print(f"\t key subset high : {hex(ids.key_subset_256.high)}")
        %}

        assert key_subset_256.low = key_shifted.low;
        assert key_subset_256.high = key_high;
        assert key_subset_last_nibble = key_shifted_last_nibble;
        return ();
    } else {
        let (_, key_low) = felt_divmod(key_shifted.low, pow2_array[4 * key_subset_nibble_len]);
        assert key_subset_256.low = key_low;
        assert key_subset_256.high = 0;
        assert key_subset_last_nibble = key_shifted_last_nibble;
        return ();
    }
}

// From a key with reverse little endian bytes of the form :
// key = n62 n63 n60 n61 n58 n59 n56 n57 n54 n55 n52 n53 n50 n51 n48 n49 n46 n47 n44 n45 n42 n43 n40 n41 n38 n39 n36 n37 n34 n35 n32 n33 n30 n31 n28 n29 n26 n27 n24 n25 n22 n23 n20 n21 n18 n19 n16 n17 n14 n15 n12 n13 n10 n11 n8 n9 n6 n7 n4 n5 n2 n3 n0 n1
// returns ni such that i = nibble_index
// Since key is assumed to be in little endian, nibble index is ordered to start from the most significant nibble for the big endian representation,
// ie : nibble_index = 0 => most significant nibble of key in big endian
func extract_nibble_from_key{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    key: Uint256, nibble_index: felt, pow2_array: felt*
) -> felt {
    alloc_locals;
    local get_nibble_from_low: felt;
    local nibble_pos: felt;
    %{
        ids.get_nibble_from_low = 1 if 0 <= ids.nibble_index <= 31 else 0
        ids.nibble_pos = ids.nibble_index % 2
    %}
    %{
        print(f"Key low: {hex(ids.key.low)}")
        print(f"Key high: {hex(ids.key.high)}")
        print(f"nibble_index: {ids.nibble_index}")
    %}
    if (get_nibble_from_low != 0) {
        if (nibble_pos != 0) {
            %{ print(f"\t case 0 ") %}
            assert [range_check_ptr] = 31 - nibble_index;
            assert bitwise_ptr.x = key.low;
            assert bitwise_ptr.y = 0xf * pow2_array[4 * (nibble_index - 1)];
            let extracted_nibble_at_pos = bitwise_ptr.x_and_y / pow2_array[4 * (nibble_index - 1)];
            tempvar range_check_ptr = range_check_ptr + 1;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
            return extracted_nibble_at_pos;
        } else {
            %{ print(f"\t case 1 ") %}

            assert [range_check_ptr] = 31 - nibble_index;
            assert bitwise_ptr.x = key.low;
            assert bitwise_ptr.y = 0xf * pow2_array[4 * nibble_index + 4];
            let extracted_nibble_at_pos = bitwise_ptr.x_and_y / pow2_array[4 * nibble_index + 4];
            tempvar range_check_ptr = range_check_ptr + 1;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
            return extracted_nibble_at_pos;
        }
    } else {
        if (nibble_pos != 0) {
            %{ print(f"\t case 2 ") %}

            assert [range_check_ptr] = 31 - (nibble_index - 32);
            tempvar offset = pow2_array[4 * (nibble_index - 32)];
            assert bitwise_ptr.x = key.high;
            assert bitwise_ptr.y = 0xf * offset;
            let extracted_nibble_at_pos = bitwise_ptr.x_and_y / offset;
            tempvar range_check_ptr = range_check_ptr + 1;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
            return extracted_nibble_at_pos;
        } else {
            %{ print(f"\t case 3 ") %}

            assert [range_check_ptr] = 31 - (nibble_index - 32);
            tempvar offset = pow2_array[4 * (nibble_index - 32) + 4];
            assert bitwise_ptr.x = key.high;
            assert bitwise_ptr.y = 0xf * offset;
            let extracted_nibble_at_pos = bitwise_ptr.x_and_y / offset;
            tempvar range_check_ptr = range_check_ptr + 1;
            tempvar bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
            return extracted_nibble_at_pos;
        }
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

// From an array of 64 bit words in little endia bytesn, extract n bytes starting at start_word and start_offset.
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

    let (q, n_ending_bytes) = felt_divmod_8(n_bytes);

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

// Jumps n items in a rlp consisting of only single byte, short string and long string items.
// params:
// - rlp: little endian 8 bytes chunks.
// - already_jumped_items: the number of items already jumped. Must be 0 at the first call.
// - n_items_to_jump: the number of items to jump in the rlp.
// - prefix_start_word: the word of the prefix to jump from.
// - prefix_start_offset: the offset of the prefix to jump from.
// - last_item_bytes_len: the number of bytes of the last item of the branch node. (Must correspond to the initial item bytes length if n_items_to_jump = 0, otherwise any value is fine)
// - pow2_array: array of powers of 2.
// returns:
// - the word number of the item to jump to.
// - the offset of the item to jump to.
// - the number of bytes of the item to jump to.
func jump_n_items_from_item{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*,
    already_jumped_items: felt,
    n_items_to_jump: felt,
    prefix_start_word: felt,
    prefix_start_offset: felt,
    last_item_bytes_len: felt,
    pow2_array: felt*,
) -> (start_word: felt, start_offset: felt, bytes_len: felt) {
    alloc_locals;

    if (already_jumped_items == n_items_to_jump) {
        return (prefix_start_word, prefix_start_offset, last_item_bytes_len);
    }

    let item_prefix = extract_byte_at_pos(rlp[prefix_start_word], prefix_start_offset, pow2_array);
    local item_type: felt;
    %{
        if 0x00 <= ids.item_prefix <= 0x7f:
            ids.item_type = 0
            #print(f"item : single byte")
        elif 0x80 <= ids.item_prefix <= 0xb7:
            ids.item_type = 1
            #print(f"item : short string at item {ids.item_start_index} {ids.item_prefix - 0x80} bytes")
        elif 0xb8 <= ids.second_item_prefix <= 0xbf:
            ids.item_type = 2
            #print(f"ong string (len_len {ids.second_item_prefix - 0xb7} bytes)")
        else:
            print(f"Unsupported item type {ids.item_prefix}. Only single bytes, short or long strings are supported.")
    %}

    if (item_type == 0) {
        // Single byte. We need to go further by one byte.
        assert [range_check_ptr] = 0x7f - item_prefix;
        tempvar range_check_ptr = range_check_ptr + 1;
        if (prefix_start_offset + 1 == 8) {
            // We need to jump to the next word.
            return jump_n_items_from_item(
                rlp,
                already_jumped_items + 1,
                n_items_to_jump,
                prefix_start_word + 1,
                0,
                1,
                pow2_array,
            );
        } else {
            return jump_n_items_from_item(
                rlp,
                already_jumped_items + 1,
                n_items_to_jump,
                prefix_start_word,
                prefix_start_offset + 1,
                1,
                pow2_array,
            );
        }
    } else {
        if (item_type == 1) {
            // Short string.
            assert [range_check_ptr] = item_prefix - 0x80;
            assert [range_check_ptr + 1] = 0xb7 - item_prefix;
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar short_string_bytes_len = item_prefix - 0x80;
            let (next_item_start_word, next_item_start_offset) = felt_divmod_8(
                prefix_start_word * 8 + prefix_start_offset + 1 + short_string_bytes_len
            );
            return jump_n_items_from_item(
                rlp,
                already_jumped_items + 1,
                n_items_to_jump,
                next_item_start_word,
                next_item_start_offset,
                short_string_bytes_len,
                pow2_array,
            );
        } else {
            // Long string.
            assert [range_check_ptr] = item_prefix - 0xb8;
            assert [range_check_ptr + 1] = 0xbf - item_prefix;
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar len_len = item_prefix - 0xb7;

            local len_len_start_word: felt;
            local len_len_start_offset: felt;

            if (prefix_start_offset + 1 == 8) {
                assert len_len_start_word = prefix_start_word + 1;
                assert len_len_start_offset = 0;
            } else {
                assert len_len_start_word = prefix_start_word;
                assert len_len_start_offset = prefix_start_offset + 1;
            }

            let (len_len_bytes, len_len_n_words) = extract_n_bytes_from_le_64_chunks_array(
                rlp, len_len_start_word, len_len_start_offset, len_len, pow2_array
            );
            assert len_len_n_words = 1;

            local long_string_bytes_len: felt;

            if (len_len == 1) {
                // No need to reverse, only one byte.
                assert long_string_bytes_len = len_len_bytes[0];
            } else {
                let (long_string_bytes_len_tmp) = word_reverse_endian_64(len_len_bytes);
                assert long_string_bytes_len = long_string_bytes_len_tmp;
            }

            let (next_item_start_word, next_item_start_offset) = felt_divmod_8(
                prefix_start_word * 8 + prefix_start_offset + 1 + len_len + long_string_bytes_len
            );

            return jump_n_items_from_item(
                rlp,
                already_jumped_items + 1,
                n_items_to_jump,
                next_item_start_word,
                next_item_start_offset,
                long_string_bytes_len,
                pow2_array,
            );
        }
    }
}
