from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys
from src.libs.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64
from src.hdp.rlp import retrieve_from_rlp_list_via_idx
from src.libs.mpt import verify_mpt_content, nibble_padding_unwrap
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
    extract_le_hash_from_le_64_chunks_array,
    assert_subset_in_key,
    extract_nibble_from_key,
)

func verify_transaction{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,

}(
    proof: felt**,
    proof_len: felt,
    bytes_len: felt*,
    key_little: Uint256,
    hash_to_assert: Uint256

) {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    verify_mpt_content{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
    }(
        mpt_proof=proof,
        mpt_proof_bytes_len=bytes_len,
        mpt_proof_len=proof_len,
        key_little=key_little,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=hash_to_assert,
        pow2_array=pow2_array,
    );

    %{ conditional_print("MPT Proof Valid! Start Decoding TX Values") %}

    let value_node_index = proof_len - 1;

    let (tx_string_prefix, tx_string_start_offset) = nibble_padding_unwrap{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(proof[value_node_index], bytes_len[value_node_index]);

    // receive long string. 
    assert [range_check_ptr] = tx_string_prefix - 0xb7;
    assert [range_check_ptr + 1] = 0xbf - tx_string_prefix;

    let len_len = tx_string_prefix - 0xb7;
    let version_byte_index = tx_string_start_offset + len_len + 1;

    %{ print("Version Byte Index:", ids.version_byte_index)%} 

    // Hashing seems to work!
    // tempvar range_check_ptr = range_check_ptr + 2;
    // let (tx_list_starts_at_word, tx_list_start_offset) = felt_divmod(
    //     version_byte_index, 8
    // );
    // let tx_bytes_len = bytes_len[value_node_index] - version_byte_index;
    // let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
    //     array=proof[value_node_index],
    //     start_word=tx_list_starts_at_word,
    //     start_offset=tx_list_start_offset,
    //     n_bytes=tx_bytes_len,
    //     pow2_array=pow2_array
    // );
    // let (hash: Uint256) = keccak(res, tx_bytes_len);
    // %{ print("Hash:", hex(ids.hash.low), hex(ids.hash.high)) %}

    let version_byte = extract_byte_at_pos(proof[value_node_index][0], version_byte_index, pow2_array);
    assert [range_check_ptr + 2] = 0x04 - version_byte;

    let range_check_ptr = range_check_ptr + 3;

    let (tx_list_starts_at_word, tx_list_start_offset) = felt_divmod(
        version_byte_index + 1, 8
    );

    // Assert long list is in string
    let list_start = extract_byte_at_pos(proof[value_node_index][tx_list_starts_at_word], tx_list_start_offset, pow2_array);
    assert [range_check_ptr] = list_start - 0xf7;
    assert [range_check_ptr + 1] = 0xff - list_start;

    tempvar range_check_ptr = range_check_ptr + 2;

    let len_len = list_start - 0xf7;
    let tx_item_start_idx = version_byte_index + 2 + len_len; // version_byte_index + 1 for version byte. + 1 for long list prefix. + len_len for length prefix.
    let rlp_bytes_len = bytes_len[value_node_index] - tx_item_start_idx;

    let (tx_items_starts_at_word, tx_items_start_offset) = felt_divmod(
        tx_item_start_idx, 8
    );

    let (rlp, rlp_len) = extract_n_bytes_from_le_64_chunks_array(
        array=proof[value_node_index],
        start_word=tx_items_starts_at_word,
        start_offset=tx_items_start_offset,
        n_bytes=rlp_bytes_len,
        pow2_array=pow2_array
    );

    let (res, res_len, res_bytes_len) = retrieve_from_rlp_list_via_idx{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(
        rlp=rlp,
        value_idx=3,
        item_starts_at_byte=0,
        counter=0,
    );

    let r0 = res[0];
    // let r1 = res[1];
    // let r2 = res[2];
    // let r3 = res[3];

    %{
        print("Res Len:", ids.res_len)
        print("Res Bytes Len:", ids.res_bytes_len)
        print("Res0:", ids.r0)
    %}
        // print("Res0:", ids.r1)
        // print("Res0:", ids.r2)
        // print("Res0:", ids.r3)


    return ();
}