from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian, felt_to_uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_felts_bigend
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

from src.types import MMRMeta
from starkware.cairo.common.memcpy import memcpy
from src.utils.merkle import compute_merkle_root

// Writes all required fields to the output_ptr.
// The first 4 words are reserved for the tasks and results root.
// The rest of the words are reserved for the MMR metas. Each MMR will contain 4 fields, and we can add an arbitrary amount of them.
func mmr_metas_write_output_ptr{output_ptr: felt*}(mmr_metas: MMRMeta*, mmr_metas_len: felt) {
    tempvar counter = 0;

    loop:
    let counter = [ap - 1];

    %{ memory[ap] = 1 if (ids.mmr_metas_len == ids.counter) else 0 %}
    jmp end_loop if [ap] != 0, ap++;

    assert [output_ptr + counter * 4] = mmr_metas[counter].id;
    assert [output_ptr + counter * 4 + 1] = mmr_metas[counter].size;
    assert [output_ptr + counter * 4 + 2] = mmr_metas[counter].chain_id;
    assert [output_ptr + counter * 4 + 3] = mmr_metas[counter].root;

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


func calculate_task_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
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
