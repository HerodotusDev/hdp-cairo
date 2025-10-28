from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian, felt_to_uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_keccak.keccak import (
    cairo_keccak_felts_bigend as keccak_felts_bigend,
)
from starkware.cairo.common.math import unsigned_div_rem
from packages.eth_essentials.lib.rlp_little import array_copy
from packages.eth_essentials.lib.utils import (
    word_reverse_endian_16_RC,
    word_reverse_endian_24_RC,
    word_reverse_endian_32_RC,
    word_reverse_endian_40_RC,
    word_reverse_endian_48_RC,
    word_reverse_endian_56_RC,
    word_reverse_endian_64,
    felt_divmod,
    get_felt_bitlength,
)

from src.types import MMRMetaPoseidon, MMRMetaKeccak
from starkware.cairo.common.memcpy import memcpy
from src.utils.merkle import compute_merkle_root

// Writes all required fields to the output_ptr.
// The first 4 words are reserved for the tasks and results root.
// The rest of the words are reserved for the MMR metas. Each MMR will contain 4 fields, and we can add an arbitrary amount of them.
func mmr_metas_write_output_ptr{output_ptr: felt*}(
    mmr_metas_poseidon: MMRMetaPoseidon*, mmr_metas_len: felt
) {
    tempvar counter = 0;

    loop:
    let counter = [ap - 1];

    %{ memory[ap] = 1 if (ids.mmr_metas_len == ids.counter) else 0 %}
    jmp end_loop if [ap] != 0, ap++;

    assert [output_ptr + counter * 4] = mmr_metas_poseidon[counter].id;
    assert [output_ptr + counter * 4 + 1] = mmr_metas_poseidon[counter].size;
    assert [output_ptr + counter * 4 + 2] = mmr_metas_poseidon[counter].chain_id;
    assert [output_ptr + counter * 4 + 3] = mmr_metas_poseidon[counter].root;

    [ap] = counter + 1, ap++;

    jmp loop;

    end_loop:
    // ensure we finish the loop
    assert counter = mmr_metas_len;
    let output_ptr = output_ptr + mmr_metas_len * 4;

    return ();
}

// reverses the endianness of chunk up to 56 bytes long
func reverse_small_chunk_endianess{range_check_ptr}(word: felt, bytes_len: felt) -> felt {
    if (bytes_len == 1) {
        return word;
    }
    if (bytes_len == 2) {
        return word_reverse_endian_16_RC{range_check_ptr=range_check_ptr}(word);
    }
    if (bytes_len == 3) {
        return word_reverse_endian_24_RC{range_check_ptr=range_check_ptr}(word);
    }
    if (bytes_len == 4) {
        return word_reverse_endian_32_RC{range_check_ptr=range_check_ptr}(word);
    }
    if (bytes_len == 5) {
        return word_reverse_endian_40_RC{range_check_ptr=range_check_ptr}(word);
    }
    if (bytes_len == 6) {
        return word_reverse_endian_48_RC{range_check_ptr=range_check_ptr}(word);
    }
    if (bytes_len == 7) {
        return word_reverse_endian_56_RC{range_check_ptr=range_check_ptr}(word);
    }

    assert 1 = 0;
    return 0;
}

// reverses the endianness of chunk, up to 64 bits long
func reverse_chunk_endianess{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    word: felt, bytes_len: felt
) -> felt {
    if (bytes_len == 1) {
        return word;
    }
    if (bytes_len == 2) {
        let res = word_reverse_endian_16_RC{range_check_ptr=range_check_ptr}(word);
        return (res);
    }
    if (bytes_len == 3) {
        let res = word_reverse_endian_24_RC{range_check_ptr=range_check_ptr}(word);
        return (res);
    }
    if (bytes_len == 4) {
        let res = word_reverse_endian_32_RC{range_check_ptr=range_check_ptr}(word);
        return (res);
    }
    if (bytes_len == 5) {
        let res = word_reverse_endian_40_RC{range_check_ptr=range_check_ptr}(word);
        return (res);
    }
    if (bytes_len == 6) {
        let res = word_reverse_endian_48_RC{range_check_ptr=range_check_ptr}(word);
        return (res);
    }
    if (bytes_len == 7) {
        let res = word_reverse_endian_56_RC{range_check_ptr=range_check_ptr}(word);
        return (res);
    }
    if (bytes_len == 8) {
        let (res) = word_reverse_endian_64{bitwise_ptr=bitwise_ptr}(word);
        return (res);
    }

    assert 1 = 0;
    return 0;
}

// Returns the number of bytes in x
// Assumption for caller:
// - 1 <= x < 2^127
// returns the number of bytes needed to represent x
func get_felt_bytes_len{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    let bit_len = get_felt_bitlength(x);
    let (bytes, rest) = felt_divmod(bit_len, 8);
    if (rest == 0) {
        return (bytes);
    } else {
        return (bytes + 1);
    }
}

func felt_array_to_uint256s{range_check_ptr}(counter: felt, retdata: felt*, leafs: Uint256*) {
    if (counter == 0) {
        return ();
    }

    let res = felt_to_uint256([retdata]);
    assert [leafs] = res;
    return felt_array_to_uint256s(counter=counter - 1, retdata=retdata + 1, leafs=leafs + 2);
}

// Mixed writer: emits both Poseidon and Keccak MMR meta sections with counts header.
// Layout:
//   [poseidon_len, keccak_len,
//    poseidon_len * (id, size, chain_id, root),
//    keccak_len   * (id, size, chain_id, root_low, root_high)]
func mmr_metas_write_output_ptr_mixed{output_ptr: felt*}(
    mmr_metas_poseidon: MMRMetaPoseidon*,
    mmr_metas_len_poseidon: felt,
    mmr_metas_keccak: MMRMetaKeccak*,
    mmr_metas_len_keccak: felt,
) {
    // Write section counts
    assert [output_ptr] = mmr_metas_len_poseidon;
    assert [output_ptr + 1] = mmr_metas_len_keccak;
    let output_ptr = output_ptr + 2;

    // Poseidon entries (4 felts each)
    tempvar i = 0;

    poseidon_loop:
    let i = [ap - 1];

    %{ memory[ap] = 1 if (ids.mmr_metas_len_poseidon == ids.i) else 0 %}
    jmp poseidon_end if [ap] != 0, ap++;

    assert [output_ptr + i * 4] = mmr_metas_poseidon[i].id;
    assert [output_ptr + i * 4 + 1] = mmr_metas_poseidon[i].size;
    assert [output_ptr + i * 4 + 2] = mmr_metas_poseidon[i].chain_id;
    assert [output_ptr + i * 4 + 3] = mmr_metas_poseidon[i].root;

    [ap] = i + 1, ap++;
    jmp poseidon_loop;

    poseidon_end:
    // advance pointer past poseidon entries
    assert i = mmr_metas_len_poseidon;
    let output_ptr = output_ptr + mmr_metas_len_poseidon * 4;

    // Keccak entries (5 felts each, ordered as id, size, chain_id, root_low, root_high)
    tempvar j = 0;

    keccak_loop:
    let j = [ap - 1];

    %{ memory[ap] = 1 if (ids.mmr_metas_len_keccak == ids.j) else 0 %}
    jmp keccak_end if [ap] != 0, ap++;

    assert [output_ptr + j * 5] = mmr_metas_keccak[j].id;
    assert [output_ptr + j * 5 + 1] = mmr_metas_keccak[j].size;
    assert [output_ptr + j * 5 + 2] = mmr_metas_keccak[j].chain_id;
    assert [output_ptr + j * 5 + 3] = mmr_metas_keccak[j].root_low;
    assert [output_ptr + j * 5 + 4] = mmr_metas_keccak[j].root_high;

    [ap] = j + 1, ap++;
    jmp keccak_loop;

    keccak_end:
    // advance pointer past keccak entries
    assert j = mmr_metas_len_keccak;
    let output_ptr = output_ptr + mmr_metas_len_keccak * 5;

    return ();
}

// Calculates the HDP Task Hash (also known as task commitment)
// That is compatibile with Solidity implementation of Data Processor Module in Satellite
// Inputs:
// module_hash: Program hash of the HDP module
// modupublic_inputs: Array of HDP Task public inputs for the module
// returns the task hash
func calculate_task_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*}(
    module_hash: felt, public_inputs_len: felt, public_inputs: felt*
) -> Uint256 {
    alloc_locals;

    let (task_hash_preimage) = alloc();
    assert task_hash_preimage[0] = module_hash;

    // This is the offset for encoding dynamic array in Solidity - data for the inputs array starts at byte position 64 -> 40 in HEX
    assert task_hash_preimage[
        1
    ] = 0x0000000000000000000000000000000000000000000000000000000000000040;

    // For Solidity encoding of array size
    assert task_hash_preimage[2] = public_inputs_len;

    memcpy(dst=task_hash_preimage + 3, src=public_inputs, len=public_inputs_len);
    tempvar task_hash_preimage_len: felt = 3 + public_inputs_len;

    let (taskHash) = keccak_felts_bigend(task_hash_preimage_len, task_hash_preimage);

    return taskHash;
}

// Helper utilities to adapt builtin-padded 64-bit lanes to raw bytes for cairo_keccak.

// Extract the byte at a given offset from a buffer of 64-bit-packed words (little-endian within word).
func get_byte_at_offset{range_check_ptr}(base: felt*, pow2_array: felt*, offset: felt) -> (
    byte: felt
) {
    alloc_locals;
    // word_index = offset // 8, in_word_offset = offset % 8
    let (word_index, in_word_offset) = unsigned_div_rem(offset, 8);
    let w = base[word_index];

    // Lanes are little-endian within each 64-bit word in the syscall buffer.
    let shift_bits = in_word_offset * 8;
    let divisor = pow2_array[shift_bits];  // 2 ** shift_bits
    let (q1, _) = unsigned_div_rem(w, divisor);
    let (_, b) = unsigned_div_rem(q1, 256);
    return (byte=b);
}

// Scan from the end of the last block: require trailing 0x80, then zeros, then 0x01.
// Return the index (in bytes from start) of the padding 0x01 byte, which equals the message length.
func find_padding_01_pos{range_check_ptr}(base: felt*, pow2_array: felt*, idx: felt) -> (
    pos: felt
) {
    alloc_locals;
    let (b) = get_byte_at_offset(base, pow2_array, idx);
    if (b == 0) {
        let (pos) = find_padding_01_pos(base, pow2_array, idx - 1);
        return (pos=pos);
    }
    // First non-zero after trailing zeros must be 0x01 (Keccak legacy domain).
    assert b = 1;
    return (pos=idx);
}

// Recover original (unpadded) message length in bytes from builtin-padded lanes.
func find_message_len_bytes{range_check_ptr}(base: felt*, len_words: felt, pow2_array: felt*) -> (
    msg_len: felt
) {
    alloc_locals;
    let total_bytes = len_words * 8;
    let last_idx = total_bytes - 1;

    // Last byte must be 0x80 in the builtin-padded representation.
    let (b_last) = get_byte_at_offset(base, pow2_array, last_idx);
    assert b_last = 128;

    // Move left to find the required 0x01 after a run of zeros.
    let (pos_01) = find_padding_01_pos(base, pow2_array, last_idx - 1);
    // Message length equals index of the 0x01 padding byte.
    return (msg_len=pos_01);
}

// Copy the first n 64-bit words from src to dst.
func copy_prefix_words_loop{range_check_ptr}(src: felt*, dst: felt*, n_words: felt, i: felt) {
    if (i == n_words) {
        return ();
    }
    assert dst[i] = src[i];
    copy_prefix_words_loop(src, dst, n_words, i + 1);
    return ();
}

func copy_prefix_words{range_check_ptr}(src: felt*, dst: felt*, n_words: felt) {
    copy_prefix_words_loop(src, dst, n_words, 0);
    return ();
}

// Build a little-endian 64-bit word from rem_bytes starting at start_offset (byte index) in base.
// This is used to supply cairo_keccak() with the tail bytes when msg_len % 8 != 0.
func build_tail_le_word_acc{range_check_ptr}(
    base: felt*, pow2_array: felt*, start_offset: felt, rem_bytes: felt, j: felt, acc: felt
) -> (res: felt) {
    if (j == rem_bytes) {
        return (res=acc);
    }
    let offset = start_offset + j;
    let (b) = get_byte_at_offset(base, pow2_array, offset);
    let factor = pow2_array[j * 8];
    let acc2 = acc + b * factor;
    let (res_rec) = build_tail_le_word_acc(
        base=base,
        pow2_array=pow2_array,
        start_offset=start_offset,
        rem_bytes=rem_bytes,
        j=j + 1,
        acc=acc2,
    );
    return (res=res_rec);
}

func build_tail_le_word{range_check_ptr}(
    base: felt*, pow2_array: felt*, start_offset: felt, rem_bytes: felt
) -> (word: felt) {
    let (res) = build_tail_le_word_acc(
        base=base, pow2_array=pow2_array, start_offset=start_offset, rem_bytes=rem_bytes, j=0, acc=0
    );
    return (word=res);
}
