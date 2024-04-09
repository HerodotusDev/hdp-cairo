from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.registers import get_fp_and_pc
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
    extract_le_hash_from_le_64_chunks_array,
    assert_subset_in_key,
    extract_nibble_from_key,
)
from src.libs.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64, get_felt_bitlength

// Verify a Merkle Patricia Tree proof.
// params:
// - mpt_proof: the proof to verify as an array of nodes, each node being an array of little endian 8 bytes chunks.
// - mpt_proof_bytes_len: array of the length in bytes of each node
// - mpt_proof_len: number of nodes in the proof
// - key_little: the key to verify as a little endian bytes Uint256
// - n_nibbles_already_checked:  the number of nibbles already checked in the key. Should start with 0.
// - node_index: the index of the next node to verify. Should start with 0.
// - hash_to_assert: the current hash to assert for the current node. Should start with the root of the MPT.
// - pow2_array: array of powers of 2.
// returns:
// - the value of the proof as a felt* array of little endian 8 bytes chunks.
// - the total length in bytes of the value.
func verify_mpt_proof{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    mpt_proof: felt**,
    mpt_proof_bytes_len: felt*,
    mpt_proof_len: felt,
    key_little: Uint256,
    n_nibbles_already_checked: felt,
    node_index: felt,
    hash_to_assert: Uint256,
    pow2_array: felt*,
) -> (value: felt*, value_len: felt) {
    alloc_locals;
    %{
        def conditional_print(*args):
            if debug_mode:
                print(*args)
        debug_mode = False
        conditional_print(f"\n\nNode index {ids.node_index+1}/{ids.mpt_proof_len}")
    %}
    if (node_index == mpt_proof_len - 1) {
        // Last node : item of interest is the value.
        // Check that the hash of the last node is the expected one.
        // Check that the final accumulated key is the expected one.
        let (node_hash: Uint256) = keccak(mpt_proof[node_index], mpt_proof_bytes_len[node_index]);
        %{ conditional_print(f"node_hash : {hex(ids.node_hash.low + 2**128*ids.node_hash.high)}") %}
        %{ conditional_print(f"hash_to_assert : {hex(ids.hash_to_assert.low + 2**128*ids.hash_to_assert.high)}") %}
        assert node_hash.low - hash_to_assert.low = 0;
        assert node_hash.high - hash_to_assert.high = 0;

        let (n_nibbles_checked, item_of_interest, item_of_interest_len) = decode_node_list_lazy(
            rlp=mpt_proof[node_index],
            bytes_len=mpt_proof_bytes_len[node_index],
            pow2_array=pow2_array,
            last_node=1,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_already_checked,
        );

        return (item_of_interest, item_of_interest_len);
    } else {
        // Not last node : item of interest is the hash of the next node.
        // Check that the hash of the current node is the expected one.

        let (node_hash: Uint256) = keccak(mpt_proof[node_index], mpt_proof_bytes_len[node_index]);
        %{ conditional_print(f"node_hash : {hex(ids.node_hash.low + 2**128*ids.node_hash.high)}") %}
        %{ conditional_print(f"hash_to_assert : {hex(ids.hash_to_assert.low + 2**128*ids.hash_to_assert.high)}") %}
        assert node_hash.low - hash_to_assert.low = 0;
        assert node_hash.high - hash_to_assert.high = 0;
        %{ conditional_print(f"\t Hash assert for node {ids.node_index} passed.") %}
        let (n_nibbles_checked, item_of_interest, item_of_interest_len) = decode_node_list_lazy(
            rlp=mpt_proof[node_index],
            bytes_len=mpt_proof_bytes_len[node_index],
            pow2_array=pow2_array,
            last_node=0,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_already_checked,
        );

        return verify_mpt_proof(
            mpt_proof=mpt_proof,
            mpt_proof_bytes_len=mpt_proof_bytes_len,
            mpt_proof_len=mpt_proof_len,
            key_little=key_little,
            n_nibbles_already_checked=n_nibbles_checked,
            node_index=node_index + 1,
            hash_to_assert=[cast(item_of_interest, Uint256*)],
            pow2_array=pow2_array,
        );
    }
}

//
func decode_node_list_lazy{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*,
    bytes_len: felt,
    pow2_array: felt*,
    last_node: felt,
    key_little: Uint256,
    n_nibbles_already_checked: felt,
) -> (n_nibbles_already_checked: felt, item_of_interest: felt*, item_of_interest_len: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let list_prefix = extract_byte_at_pos(rlp[0], 0, pow2_array);
    local long_short_list: felt;  // 0 for short, !=0 for long.
    %{
        if 0xc0 <= ids.list_prefix <= 0xf7:
            ids.long_short_list = 0
            conditional_print("List type : short")
        elif 0xf8 <= ids.list_prefix <= 0xff:
            ids.long_short_list = 1
            conditional_print("List type: long")
        else:
            conditional_print("Not a list.")
    %}
    local first_item_start_offset: felt;
    local list_len: felt;  // Bytes length of the list. (not including the prefix)

    if (long_short_list != 0) {
        // Long list.
        assert [range_check_ptr] = list_prefix - 0xf8;
        assert [range_check_ptr + 1] = 0xff - list_prefix;
        let len_len = list_prefix - 0xf7;
        assert first_item_start_offset = 1 + len_len;
        assert list_len = bytes_len - len_len - 1;
    } else {
        // Short list.
        assert [range_check_ptr] = list_prefix - 0xc0;
        assert [range_check_ptr + 1] = 0xf7 - list_prefix;
        assert first_item_start_offset = 1;
        assert list_len = list_prefix - 0xc0;
    }
    // At this point, if input is neither a long nor a short list, then the range check will fail.
    // %{ conditional_print("list_len", ids.list_len) %}
    // %{ conditional_print("first word", memory[ids.rlp]) %}
    assert [range_check_ptr + 2] = 7 - first_item_start_offset;
    // We now need to differentiate between the type of nodes: extension/leaf or branch.

    // %{ conditional_print("first item starts at byte", ids.first_item_start_offset) %}
    let first_item_prefix = extract_byte_at_pos(rlp[0], first_item_start_offset, pow2_array);

    // %{ conditional_print("First item prefix", hex(ids.first_item_prefix)) %}
    // Regardless of leaf, extension or branch, the first item should always be less than 32 bytes so a short string / single byte :
    // 0-55 bytes string long
    // (range [0x80, 0xb7] (dec. [128, 183])).

    local first_item_type;
    local first_item_len;
    local second_item_starts_at_byte;
    %{
        if 0 <= ids.first_item_prefix <= 0x7f:
            ids.first_item_type = 0 # Single byte
        elif 0x80 <= ids.first_item_prefix <= 0xb7:
            ids.first_item_type = 1 # Short string
        else:
            print(f"Unsupported first item type for prefix {ids.first_item_prefix=}")
    %}
    if (first_item_type != 0) {
        // Short string
        assert [range_check_ptr + 3] = first_item_prefix - 0x80;
        assert [range_check_ptr + 4] = 0xb7 - first_item_prefix;
        assert first_item_len = first_item_prefix - 0x80;
        assert second_item_starts_at_byte = first_item_start_offset + 1 + first_item_len;
        tempvar range_check_ptr = range_check_ptr + 5;
    } else {
        // Single byte
        assert [range_check_ptr + 3] = 0x7f - first_item_prefix;
        assert first_item_len = 1;
        assert second_item_starts_at_byte = first_item_start_offset + first_item_len;
        tempvar range_check_ptr = range_check_ptr + 4;
    }
    // %{ conditional_print("first item len:", ids.first_item_len, "bytes") %}
    // %{ conditional_print("second_item_starts_at_byte", ids.second_item_starts_at_byte) %}
    let (second_item_starts_at_word, second_item_start_offset) = felt_divmod(
        second_item_starts_at_byte, 8
    );
    // %{ conditional_print("second_item_starts_at_word", ids.second_item_starts_at_word) %}
    // %{ conditional_print("second_item_start_offset", ids.second_item_start_offset) %}
    // %{ conditional_print("second_item_first_word", memory[ids.rlp + ids.second_item_starts_at_word]) %}

    let second_item_prefix = extract_byte_at_pos(
        rlp[second_item_starts_at_word], second_item_start_offset, pow2_array
    );
    // %{ conditional_print("second_item_prefix", hex(ids.second_item_prefix)) %}
    local second_item_type: felt;
    %{
        if 0x00 <= ids.second_item_prefix <= 0x7f:
            ids.second_item_type = 0
            conditional_print(f"2nd item : single byte")
        elif 0x80 <= ids.second_item_prefix <= 0xb7:
            ids.second_item_type = 1
            conditional_print(f"2nd item : short string {ids.second_item_prefix - 0x80} bytes")
        elif 0xb8 <= ids.second_item_prefix <= 0xbf:
            ids.second_item_type = 2
            conditional_print(f"2nd item : long string (len_len {ids.second_item_prefix - 0xb7} bytes)")
        else:
            conditional_print(f"2nd item : unknown type {ids.second_item_prefix}")
    %}

    local second_item_bytes_len;
    local second_item_value_starts_at_byte;
    local third_item_starts_at_byte;
    local range_check_ptr_f;
    local bitwise_ptr_f: BitwiseBuiltin*;
    if (second_item_type == 0) {
        // Single byte.
        assert [range_check_ptr] = 0x7f - second_item_prefix;
        assert second_item_bytes_len = 1;
        assert second_item_value_starts_at_byte = second_item_starts_at_byte;
        assert third_item_starts_at_byte = second_item_starts_at_byte + second_item_bytes_len;
        assert range_check_ptr_f = range_check_ptr + 1;
        assert bitwise_ptr_f = bitwise_ptr;
    } else {
        if (second_item_type == 1) {
            // Short string.
            assert [range_check_ptr] = second_item_prefix - 0x80;
            assert [range_check_ptr + 1] = 0xb7 - second_item_prefix;
            assert second_item_bytes_len = second_item_prefix - 0x80;
            assert second_item_value_starts_at_byte = second_item_starts_at_byte + 1;
            assert third_item_starts_at_byte = second_item_starts_at_byte + 1 +
                second_item_bytes_len;
            assert range_check_ptr_f = range_check_ptr + 2;
            assert bitwise_ptr_f = bitwise_ptr;
        } else {
            // Long string.
            assert [range_check_ptr] = second_item_prefix - 0xb8;
            assert [range_check_ptr + 1] = 0xbf - second_item_prefix;
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar len_len = second_item_prefix - 0xb7;
            assert second_item_value_starts_at_byte = second_item_starts_at_byte + 1 + len_len;
            let (second_item_len_len_start_word, second_item_len_len_start_offset) = felt_divmod_8(
                second_item_starts_at_byte + 1
            );
            if (len_len == 1) {
                // No need to reverse endian since it's a single byte.
                let second_item_long_string_len = extract_byte_at_pos(
                    rlp[second_item_len_len_start_word],
                    second_item_len_len_start_offset,
                    pow2_array,
                );
                assert second_item_bytes_len = second_item_long_string_len;
                tempvar bitwise_ptr = bitwise_ptr;
                tempvar range_check_ptr = range_check_ptr;
            } else {
                let (
                    second_item_long_string_len_ptr, n_words
                ) = extract_n_bytes_from_le_64_chunks_array(
                    array=rlp,
                    start_word=second_item_len_len_start_word,
                    start_offset=second_item_len_len_start_offset,
                    n_bytes=len_len,
                    pow2_array=pow2_array,
                );
                assert n_words = 1;  // Extremely large size for long strings forbidden.

                let second_item_long_string_len = [second_item_long_string_len_ptr];
                let (tmp) = word_reverse_endian_64(second_item_long_string_len);
                assert second_item_bytes_len = tmp / pow2_array[64 - 8 * len_len];
                tempvar bitwise_ptr = bitwise_ptr;
                tempvar range_check_ptr = range_check_ptr;
            }

            %{ conditional_print(f"second_item_long_string_len : {ids.second_item_bytes_len} bytes") %}
            assert third_item_starts_at_byte = second_item_starts_at_byte + 1 + len_len +
                second_item_bytes_len;
            assert range_check_ptr_f = range_check_ptr;
            assert bitwise_ptr_f = bitwise_ptr;
        }
    }
    let range_check_ptr = range_check_ptr_f;
    let bitwise_ptr = bitwise_ptr_f;
    // %{ conditional_print(f"second_item_bytes_len : {ids.second_item_bytes_len} bytes") %}
    // %{ conditional_print(f"third item starts at byte {ids.third_item_starts_at_byte}") %}

    if (third_item_starts_at_byte == bytes_len) {
        %{ conditional_print("two items => Leaf/Extension case") %}

        // Node's list has only 2 items : it's a leaf or an extension.
        // Regardless, we need to decode the first item (key or key_end) and the second item (hash or value).
        // actual item value starts at byte first_item_start_offset + 1 (after the prefix)
        // Get the very first nibble.

        // Ensure first_item_type is either 0 or 1.
        assert (first_item_type - 1) * (first_item_type) = 0;

        let first_item_prefix = extract_nibble_at_byte_pos(
            rlp[0], first_item_start_offset + first_item_type, 0, pow2_array
        );
        %{
            prefix = ids.first_item_prefix
            if prefix == 0:
                conditional_print("First item is an extension node, even number of nibbles")
            elif prefix == 1:
                conditional_print("First item is an extension node, odd number of nibbles")
            elif prefix == 2:
                conditional_print("First item is a leaf node, even number of nibbles")
            elif prefix == 3:
                conditional_print("First item is a leaf node, odd number of nibbles")
            else:
                raise Exception(f"Unknown prefix {prefix} for MPT node with 2 items")
        %}
        local odd: felt;
        if (first_item_prefix == 0) {
            assert odd = 0;
        } else {
            if (first_item_prefix == 2) {
                assert odd = 0;
            } else {
                // 1 & 3 case.
                assert odd = 1;
            }
        }
        tempvar n_nibbles_in_first_item = 2 * first_item_len - odd;
        %{ conditional_print(f"n_nibbles_in_first_item : {ids.n_nibbles_in_first_item}") %}
        // Extract the key or key_end.
        let (local first_item_value_start_word, local first_item_value_start_offset) = felt_divmod(
            first_item_start_offset + first_item_type + 1 - odd, 8
        );
        let (
            extracted_key_subset, extracted_key_subset_len
        ) = extract_n_bytes_from_le_64_chunks_array(
            rlp,
            first_item_value_start_word,
            first_item_value_start_offset,
            first_item_len - first_item_type + odd,
            pow2_array,
        );
        %{
            #conditional_print_array(ids.extracted_key_subset, ids.extracted_key_subset_len) 
            conditional_print(f"nibbles already checked: {ids.n_nibbles_already_checked}")
        %}

        if (first_item_type != 0) {
            // If the first item is not a single byte, verify subset in key.
            assert_subset_in_key(
                key_subset=extracted_key_subset,
                key_subset_len=extracted_key_subset_len,
                key_subset_nibble_len=n_nibbles_in_first_item,
                key_little=key_little,
                n_nibbles_already_checked=n_nibbles_already_checked,
                cut_nibble=odd,
                pow2_array=pow2_array,
            );
            tempvar range_check_ptr = range_check_ptr;
            tempvar bitwise_ptr = bitwise_ptr;
            tempvar pow2_array = pow2_array;
        } else {
            // if the first item is a single byte, skip subset verification and assert n_nibbles_already_checked == n_nibbles_in_key
            local key_bits;
            with pow2_array {
                if (key_little.high != 0) {
                    let key_bit_high = get_felt_bitlength(key_little.high);
                    assert key_bits = 128 + key_bit_high;
                } else {
                    let key_bit_low = get_felt_bitlength(key_little.low);
                    assert key_bits = key_bit_low;
                }
            }
            let (n_nibbles_in_key, remainder) = felt_divmod(key_bits, 4);
            assert remainder = 0;
            assert n_nibbles_in_key = n_nibbles_already_checked;
            tempvar range_check_ptr = range_check_ptr;
            tempvar bitwise_ptr = bitwise_ptr;
            tempvar pow2_array = pow2_array;
        }
        let range_check_ptr = range_check_ptr;
        let bitwise_ptr = bitwise_ptr;
        let pow2_array = pow2_array;

        // Extract the hash or value.

        if (last_node != 0) {
            // Extract value
            let (value_starts_word, value_start_offset) = felt_divmod(
                second_item_value_starts_at_byte, 8
            );
            let (value, value_len) = extract_n_bytes_from_le_64_chunks_array(
                rlp, value_starts_word, value_start_offset, second_item_bytes_len, pow2_array
            );
            return (
                n_nibbles_already_checked=n_nibbles_already_checked,
                item_of_interest=value,
                item_of_interest_len=second_item_bytes_len,
            );
        } else {
            // Extract hash (32 bytes)
            assert second_item_bytes_len = 32;
            let (local hash_le: Uint256) = extract_le_hash_from_le_64_chunks_array(
                rlp, second_item_starts_at_word, second_item_start_offset, pow2_array
            );
            return (
                n_nibbles_already_checked=n_nibbles_already_checked,
                item_of_interest=cast(&hash_le, felt*),
                item_of_interest_len=32,
            );
        }
    } else {
        // Node has more than 2 items : it's a branch.
        if (last_node != 0) {
            %{ conditional_print(f"Branch case, last node : yes") %}

            // Branch is the last node in the proof. We need to extract the last item (17th).
            // Key should already be fully checked at this point.
            let (third_item_start_word, third_item_start_offset) = felt_divmod(
                third_item_starts_at_byte, 8
            );
            let (
                last_item_start_word, last_item_start_offset
            ) = jump_branch_node_till_element_at_index(
                rlp, 0, 16, third_item_start_word, third_item_start_offset, pow2_array
            );
            tempvar last_item_bytes_len = bytes_len - (
                last_item_start_word * 8 + last_item_start_offset
            );
            let (last_item: felt*, last_item_len: felt) = extract_n_bytes_from_le_64_chunks_array(
                rlp, last_item_start_word, last_item_start_offset, last_item_bytes_len, pow2_array
            );

            return (n_nibbles_already_checked, last_item, last_item_bytes_len);
        } else {
            %{ conditional_print(f"Branch case, last node : no") %}
            // Branch is not the last node in the proof. We need to extract the hash corresponding to the next nibble of the key.

            // Get the next nibble of the key.
            let next_key_nibble = extract_nibble_from_key(
                key_little, n_nibbles_already_checked, pow2_array
            );
            %{ conditional_print(f"Next Key nibble {ids.next_key_nibble}") %}
            local item_of_interest_start_word: felt;
            local item_of_interest_start_offset: felt;
            local range_check_ptr_f;
            local bitwise_ptr_f: BitwiseBuiltin*;
            if (next_key_nibble == 0) {
                // Store coordinates of the first item's value.
                %{ conditional_print(f"\t Branch case, key index = 0") %}
                assert item_of_interest_start_word = 0;
                assert item_of_interest_start_offset = first_item_start_offset + 1;
                assert range_check_ptr_f = range_check_ptr;
                assert bitwise_ptr_f = bitwise_ptr;
            } else {
                if (next_key_nibble == 1) {
                    // Store coordinates of the second item's value.
                    %{ conditional_print(f"\t Branch case, key index = 1") %}
                    let (
                        second_item_value_start_word, second_item_value_start_offset
                    ) = felt_divmod_8(second_item_value_starts_at_byte);
                    assert item_of_interest_start_word = second_item_value_start_word;
                    assert item_of_interest_start_offset = second_item_value_start_offset;
                    assert range_check_ptr_f = range_check_ptr;
                    assert bitwise_ptr_f = bitwise_ptr;
                } else {
                    if (next_key_nibble == 2) {
                        // Store coordinates of the third item's value.
                        %{ conditional_print(f"\t Branch case, key index = 2") %}
                        let (
                            third_item_value_start_word, third_item_value_start_offset
                        ) = felt_divmod_8(third_item_starts_at_byte + 1);
                        assert item_of_interest_start_word = third_item_value_start_word;
                        assert item_of_interest_start_offset = third_item_value_start_offset;
                        assert range_check_ptr_f = range_check_ptr;
                        assert bitwise_ptr_f = bitwise_ptr;
                    } else {
                        // Store coordinates of the item's value at index next_key_nibble != (0, 1, 2).
                        %{ conditional_print(f"\t Branch case, key index {ids.next_key_nibble}") %}
                        let (third_item_start_word, third_item_start_offset) = felt_divmod(
                            third_item_starts_at_byte, 8
                        );
                        let (
                            item_start_word, item_start_offset
                        ) = jump_branch_node_till_element_at_index(
                            rlp=rlp,
                            item_start_index=2,
                            target_index=next_key_nibble,
                            prefix_start_word=third_item_start_word,
                            prefix_start_offset=third_item_start_offset,
                            pow2_array=pow2_array,
                        );
                        let (item_value_start_word, item_value_start_offset) = felt_divmod(
                            item_start_word * 8 + item_start_offset + 1, 8
                        );
                        assert item_of_interest_start_word = item_value_start_word;
                        assert item_of_interest_start_offset = item_value_start_offset;
                        assert range_check_ptr_f = range_check_ptr;
                        assert bitwise_ptr_f = bitwise_ptr;
                    }
                }
            }
            let range_check_ptr = range_check_ptr_f;
            let bitwise_ptr = bitwise_ptr_f;
            // Extract the hash at the correct coordinates.

            let (local hash_le: Uint256) = extract_le_hash_from_le_64_chunks_array(
                rlp, item_of_interest_start_word, item_of_interest_start_offset, pow2_array
            );

            // Return the Uint256 hash as a felt* of length 2.
            return (n_nibbles_already_checked + 1, cast(&hash_le, felt*), 32);
        }
    }
}

// Jumps on a branch until index i is reached.
// params:
// - rlp: the branch node as an array of little endian 8 bytes chunks.
// - item_start_index: the index of the item to jump from.
// - target_index: the index of the item to jump to.
// - prefix_start_word: the word of the prefix to jump from. (Must correspond to item_start_index)
// - prefix_start_offset: the offset of the prefix to jump from. (Must correspond to item_start_index)
// - pow2_array: array of powers of 2.
// returns:
// - the word number of the item to jump to.
// - the offset of the item to jump to.
func jump_branch_node_till_element_at_index{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*,
    item_start_index: felt,
    target_index: felt,
    prefix_start_word: felt,
    prefix_start_offset: felt,
    pow2_array: felt*,
) -> (start_word: felt, start_offset: felt) {
    alloc_locals;

    if (item_start_index == target_index) {
        return (prefix_start_word, prefix_start_offset);
    }

    let item_prefix = extract_byte_at_pos(rlp[prefix_start_word], prefix_start_offset, pow2_array);
    local item_type: felt;
    %{
        if 0x00 <= ids.item_prefix <= 0x7f:
            ids.item_type = 0
            #conditional_print(f"item : single byte")
        elif 0x80 <= ids.item_prefix <= 0xb7:
            ids.item_type = 1
            #conditional_print(f"item : short string at item {ids.item_start_index} {ids.item_prefix - 0x80} bytes")
        else:
            conditional_print(f"item : unknown type {ids.item_prefix} for a branch node. Should be single byte or short string only.")
    %}

    if (item_type == 0) {
        // Single byte. We need to go further by one byte.
        assert [range_check_ptr] = 0x7f - item_prefix;
        tempvar range_check_ptr = range_check_ptr + 1;
        if (prefix_start_offset + 1 == 8) {
            // We need to jump to the next word.
            return jump_branch_node_till_element_at_index(
                rlp, item_start_index + 1, target_index, prefix_start_word + 1, 0, pow2_array
            );
        } else {
            return jump_branch_node_till_element_at_index(
                rlp,
                item_start_index + 1,
                target_index,
                prefix_start_word,
                prefix_start_offset + 1,
                pow2_array,
            );
        }
    } else {
        // Short string.
        assert [range_check_ptr] = item_prefix - 0x80;
        assert [range_check_ptr + 1] = 0xb7 - item_prefix;
        tempvar range_check_ptr = range_check_ptr + 2;
        tempvar short_string_bytes_len = item_prefix - 0x80;
        let (next_item_start_word, next_item_start_offset) = felt_divmod_8(
            prefix_start_word * 8 + prefix_start_offset + 1 + short_string_bytes_len
        );
        return jump_branch_node_till_element_at_index(
            rlp,
            item_start_index + 1,
            target_index,
            next_item_start_word,
            next_item_start_offset,
            pow2_array,
        );
    }
}
