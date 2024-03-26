from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys
from src.libs.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64
from src.hdp.rlp import retrieve_from_rlp_list_via_idx
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
    extract_le_hash_from_le_64_chunks_array,
    assert_subset_in_key,
    extract_nibble_from_key,
)
from src.hdp.types import TransactionProof, Transaction, Header
from src.hdp.memorizer import HeaderMemorizer, TransactionMemorizer

from src.hdp.decoders.transaction_decoder import TransactionReader, TransactionConsensusReader

func verify_n_transaction_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    transactions: Transaction*,
    transaction_dict: DictAccess*,
    headers: Header*,
    header_dict: DictAccess*,
    pow2_array: felt*
}(tx_proofs: TransactionProof*, tx_proofs_len: felt, index: felt) {
    alloc_locals;

    if(tx_proofs_len == index) {
        return ();
    }

    // ToDo: fetch real root via memorizer
    let tx_root = Uint256(low=257761197311116532837196150678159856969, high=159425385474712577316496950941176039553);

    let tx_proof = tx_proofs[index];

    let (tx_str, tx_str_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
    }(
        mpt_proof=tx_proof.proof,
        mpt_proof_bytes_len=tx_proof.bytes_len,
        mpt_proof_len=tx_proof.len,
        key_little=tx_proof.key,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=tx_root,
        pow2_array=pow2_array,
    );

    let tx_type = extract_byte_at_pos(tx_str[0], 0, pow2_array);

    let long_list_prefix = extract_byte_at_pos(tx_str[0], 1, pow2_array);
    // Signature has 65 byte already, so tx must be a long list
    assert [range_check_ptr] = long_list_prefix - 0xf8;
    assert [range_check_ptr + 1] = 0xff - long_list_prefix;

    let len_len = long_list_prefix - 0xf7;
    let tx_start_offset = 2 + len_len; // version + long list + len_len
    assert [range_check_ptr + 2] = 7 - tx_start_offset;

    local bytes_len = tx_str_len - tx_start_offset;

    tempvar range_check_ptr = range_check_ptr + 3;
    let (rlp, rlp_len) = extract_n_bytes_from_le_64_chunks_array(
        array=tx_str,
        start_word=0,
        start_offset=tx_start_offset,
        n_bytes=bytes_len,
        pow2_array=pow2_array
    );

    assert transactions[index] = Transaction(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=tx_type
    );

    // ToDo: Decode nonce and sender
    let (sender) = alloc();
    assert sender[0] = 0;
    assert sender[1] = 0;
    assert sender[2] = 0;

    TransactionConsensusReader.get_signer_addrs(transactions[index]);

    let nonce = TransactionReader.get_nonce(rlp);
    TransactionMemorizer.add(sender, nonce, index);

    return verify_n_transaction_proofs(
        tx_proofs=tx_proofs,
        tx_proofs_len=tx_proofs_len,
        index=index + 1
    );

}

// func verify_transaction_proof{
//     range_check_ptr,
//     bitwise_ptr: BitwiseBuiltin*,
//     keccak_ptr: KeccakBuiltin*,
//     transactions: Transaction*,
//     headers: Header*,
//     header_dict: DictAccess*,
// }(tx_index: felt, tx_proof: TransactionProof) {
//     alloc_locals;
//     let pow2_array: felt* = pow2alloc128();

//     // let header = HeaderMemorizer.get(account_proof.block_number);
//     // let tx_root = HeaderDecoder.get_tx_root(header.rlp);

//     let tx_root = Uint256(low=257761197311116532837196150678159856969, high=159425385474712577316496950941176039553);

//     let (tx_str, tx_str_len) = verify_mpt_proof{
//         range_check_ptr=range_check_ptr,
//         bitwise_ptr=bitwise_ptr,
//         keccak_ptr=keccak_ptr,
//     }(
//         mpt_proof=proof,
//         mpt_proof_bytes_len=bytes_len,
//         mpt_proof_len=proof_len,
//         key_little=key_little,
//         n_nibbles_already_checked=0,
//         node_index=0,
//         hash_to_assert=tx_root,
//         pow2_array=pow2_array,
//     );

//     let tx_type = extract_byte_at_pos(tx_str[0], 0, pow2_array);

//     let long_list_prefix = extract_byte_at_pos(tx_str[0], 1, pow2_array);
//     // Signature has 65 byte already, so tx must be a long list
//     assert [range_check_ptr] = long_list_prefix - 0xf8;
//     assert [range_check_ptr + 1] = 0xff - long_list_prefix;

//     let len_len = long_list_prefix - 0xf7;
//     let tx_start_offset = 2 + len_len; // version + long list + len_len
//     assert [range_check_ptr + 2] = 7 - tx_start_offset;

//     let bytes_len = tx_str_len - tx_start_offset;

//     tempvar range_check_ptr = range_check_ptr + 3;
//     let (rlp, rlp_len) = extract_n_bytes_from_le_64_chunks_array(
//         array=tx_str,
//         start_word=0,
//         start_offset=tx_start_offset,
//         n_bytes=bytes_len,
//         pow2_array=pow2_array
//     );







    // // receive long string. 

    // let len_len = tx_string_prefix - 0xb7;
    // let tx_type_index = tx_string_start_offset + len_len + 1;

    // %{ print("Version Byte Index:", ids.tx_type_index)%} 

    // Hashing seems to work!
    // tempvar range_check_ptr = range_check_ptr + 2;
    // let (tx_list_starts_at_word, tx_list_start_offset) = felt_divmod(
    //     tx_type_index, 8
    // );
    // let tx_bytes_len = bytes_len[value_node_index] - tx_type_index;
    // let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
    //     array=proof[value_node_index],
    //     start_word=tx_list_starts_at_word,
    //     start_offset=tx_list_start_offset,
    //     n_bytes=tx_bytes_len,
    //     pow2_array=pow2_array
    // );
    // let (hash: Uint256) = keccak(res, tx_bytes_len);
    // %{ print("Hash:", hex(ids.hash.low), hex(ids.hash.high)) %}

    // let tx_type = extract_byte_at_pos(proof[value_node_index][0], tx_type_index, pow2_array);
    // assert [range_check_ptr + 2] = 0x04 - tx_type;

    // let range_check_ptr = range_check_ptr + 3;

    // let (tx_list_starts_at_word, tx_list_start_offset) = felt_divmod(
    //     tx_type_index + 1, 8
    // );

    // // Assert long list is in string
    // let list_start = extract_byte_at_pos(proof[value_node_index][tx_list_starts_at_word], tx_list_start_offset, pow2_array);
    // assert [range_check_ptr] = list_start - 0xf7;
    // assert [range_check_ptr + 1] = 0xff - list_start;

    // tempvar range_check_ptr = range_check_ptr + 2;

    // let len_len = list_start - 0xf7;
    // let tx_item_start_idx = tx_type_index + 2 + len_len; // tx_type_index + 1 for version byte. + 1 for long list prefix. + len_len for length prefix.
    // let rlp_bytes_len = bytes_len[value_node_index] - tx_item_start_idx;

    // let (tx_items_starts_at_word, tx_items_start_offset) = felt_divmod(
    //     tx_item_start_idx, 8
    // );

    // let (rlp, rlp_len) = extract_n_bytes_from_le_64_chunks_array(
    //     array=proof[value_node_index],
    //     start_word=tx_items_starts_at_word,
    //     start_offset=tx_items_start_offset,
    //     n_bytes=rlp_bytes_len,
    //     pow2_array=pow2_array
    // );

    // let (res, res_len, res_bytes_len) = retrieve_from_rlp_list_via_idx{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array,
    // }(
    //     rlp=rlp,
    //     value_idx=3,
    //     item_starts_at_byte=0,
    //     counter=0,
    // );

    // let r0 = res[0];
    // let r1 = res[1];
    // let r2 = res[2];
    // let r3 = res[3];

    // %{
    //     print("Res Len:", ids.res_len)
    //     print("Res Bytes Len:", ids.res_bytes_len)
    //     print("Res0:", ids.r0)
    // %}
        // print("Res0:", ids.r1)
        // print("Res0:", ids.r2)
        // print("Res0:", ids.r3)


//     return ();
// }