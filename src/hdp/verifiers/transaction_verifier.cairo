from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import recover_public_key, public_key_point_to_eth_address, verify_eth_signature
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
from starkware.cairo.common.cairo_secp.bigint import (
    BigInt3,
    uint256_to_bigint,
)

from src.hdp.utils import prepend_le_rlp_list_prefix

from src.hdp.types import TransactionProof, Transaction, Header
from src.hdp.memorizer import HeaderMemorizer, TransactionMemorizer

from src.hdp.decoders.transaction_decoder import TransactionReader

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

    let (tx_item, tx_item_len) = verify_mpt_proof{
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

    let first_byte = extract_byte_at_pos(tx_item[0], 0, pow2_array);
    let second_byte = extract_byte_at_pos(tx_item[0], 1, pow2_array);

    local has_type_prefix: felt;
    %{
        if ids.first_byte < 0x04:
            ids.has_type_prefix = 1
        else:
            ids.has_type_prefix = 0
    %}

    local tx_type: felt;
    local tx_start_offset: felt;
    if(has_type_prefix == 1) {
        assert [range_check_ptr] = 0x3 - first_byte; // current the highest tx type is 3
        assert [range_check_ptr + 1] = 0xff - second_byte;
        assert [range_check_ptr + 2] = second_byte - 0xf7;
        tempvar range_check_ptr = range_check_ptr + 3;

        assert tx_type = first_byte;
        let len_len = second_byte - 0xf7;
        assert tx_start_offset = 2 + len_len;  // type + prefix + len_len
    } else {
        assert [range_check_ptr] = 0xff - first_byte;
        assert [range_check_ptr + 1] = first_byte - 0xf7;
        assert [range_check_ptr + 2] = 7 - tx_start_offset;
        tempvar range_check_ptr = range_check_ptr + 3;

        assert tx_type = 0;
        let len_len = first_byte - 0xf7;
        assert tx_start_offset = 1 + len_len;
    }

    let tx_bytes_len = tx_item_len - tx_start_offset;
    // retrieve the encoded tx rlp fields
    let (tx_rlp, tx_rlp_len) = extract_n_bytes_from_le_64_chunks_array(
        array=tx_item,
        start_word=0,
        start_offset=tx_start_offset,
        n_bytes=tx_bytes_len,
        pow2_array=pow2_array
    );

    let tx = Transaction(
        rlp=tx_rlp,
        rlp_len=tx_rlp_len,
        bytes_len=tx_bytes_len,
        type=tx_type
    );
    assert transactions[index] = tx;


    let unsigned_tx_bytes_len = tx_bytes_len - 67; // 65 for sig, 2 for s & v len prefix
    %{ print("unsigned tx bytes len:", ids.unsigned_tx_bytes_len) %}
    let (unsigned_tx_rlp, unsigned_tx_rlp_len) = extract_n_bytes_from_le_64_chunks_array(
        array=tx_rlp,
        start_word=0,
        start_offset=0,
        n_bytes=unsigned_tx_bytes_len,
        pow2_array=pow2_array
    );

    local unsigned_prefix: felt;
    local unsigned_prefix_bytes_len: felt;
    %{  
        from tools.py.utils import (
            reverse_endian,
            int_get_bytes_len
        
        )
        # should be fine without validating, as its just encoding, and not tx content
        if ids.unsigned_tx_bytes_len < 55:
            prefix = 0xc0 + ids.unsigned_tx_bytes_len
        else:
            len_len_bytes = len(bytes.fromhex(hex(ids.unsigned_tx_bytes_len)[2:]))
            rlp_id = 0xf7 + len_len_bytes
            prefix = (rlp_id << (8 * len_len_bytes)) | ids.unsigned_tx_bytes_len

        # This hint is already validated above, preventing tx version replays
        if(ids.has_type_prefix == 1):
            ids.unsigned_prefix = reverse_endian(ids.tx_type << 8 | prefix)
        else:
            ids.unsigned_prefix = reverse_endian(prefix)

        ids.unsigned_prefix_bytes_len = int_get_bytes_len(ids.unsigned_prefix)
    %}

    // reencode the tx
    let (encoded_tx, encoded_tx_len) = prepend_le_rlp_list_prefix(
        offset=unsigned_prefix_bytes_len,
        prefix=unsigned_prefix,
        rlp=unsigned_tx_rlp,
        rlp_len=unsigned_tx_rlp_len
    );
    let encoded_tx_bytes_len = unsigned_tx_bytes_len + unsigned_prefix_bytes_len;
    
    let v = TransactionReader.get_field_by_index(tx, 6);
    let r = TransactionReader.get_field_by_index(tx, 7);
    let s = TransactionReader.get_field_by_index(tx, 8);

    %{
        print("V:", hex(ids.v.low), hex(ids.v.high))
        print("R:", hex(ids.r.low), hex(ids.r.high))
        print("S:", hex(ids.s.low), hex(ids.s.high))
        print("Encoded Bytes len:", ids.encoded_tx_bytes_len)
    %}


    let (big_r) = uint256_to_bigint(r);
    let (big_s) = uint256_to_bigint(s);
    let (msg_hash) = keccak_bigend(encoded_tx, encoded_tx_bytes_len);

    let (big_msg_hash) = uint256_to_bigint(msg_hash);
    let (pub) = recover_public_key(big_msg_hash, big_r, big_s, v.low);

    local address: felt;
    let (keccak_ptr_seg: felt*) = alloc();
    local keccak_ptr_seg_start: felt* = keccak_ptr_seg;
    with keccak_ptr_seg {

        let (local public_address) = public_key_point_to_eth_address{
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr,
            keccak_ptr=keccak_ptr_seg
        }(pub);

        assert address = public_address;
        finalize_keccak(keccak_ptr_start=keccak_ptr_seg_start, keccak_ptr_end=keccak_ptr_seg);

    }
    %{
        print("Address:", hex(ids.address))
    %}

    // 0xd97091c357fdd0a9b66f8315267fce9d6839340

    // 0x7Cd6BF329dBD94f699d204eD83F65D5d6b8a9E8C



    // let casted_keccak_ptr = cast(keccak_ptr, felt*);
    // let (sender) = public_key_point_to_eth_address{
        // range_check_ptr=range_check_ptr,
        // bitwise_ptr=bitwise_ptr,
        // keccak_ptr=casted_keccak_ptr
    // }(pub);

    // TransactionConsensusReader.get_signer_addrs(transactions[index]);

    // let nonce = TransactionReader.get_nonce(tx);
    // TransactionMemorizer.add(sender, nonce, index);

    return verify_n_transaction_proofs(
        tx_proofs=tx_proofs,
        tx_proofs_len=tx_proofs_len,
        index=index + 1
    );

}


// Full Tx: 02f87201058402321262850fd724715f8252089407d03a66c2fd7b9e60b4ae1177ca439d967884bb872386f26fc1000080c080a0bc5b3c58d31f7c2669f0a845c2d91dec54591afe735f074423ef69cb6d9a3387a05b07a387267212c53fdb35cc60321a546ea207d77b028327d836d3c8764f6ebe
// Tx no sig: 02f87201058402321262850fd724715f8252089407d03a66c2fd7b9e60b4ae1177ca439d967884bb872386f26fc1000080c0



// 0, 0x07c0100aca8aeacfcec12a205cb94ff1cae35773bc6b3b54c9a50f69bee29877, 0x55b737e29a863593ab5eec5e7dd9ae783a12035f979da77dd0a91c8fe19fb055, 0x62562d864115562f4b0544d15fb591773f70c288632cccace784f1efacd034f3
    // local signed_len: felt;
    // local signed_bytes_len: felt;
    // let (signed_rlp: felt*) = alloc();
    // let (unsigned_rlp: felt*) = alloc();
    // local unsigned_bytes_len : felt;

    // %{
    //     from tools.py.utils import (
    //         bytes_to_8_bytes_chunks_little,
    //     )

    //     signed_bytes = bytes.fromhex("01058402321262850fd724715f8252089407d03a66c2fd7b9e60b4ae1177ca439d967884bb872386f26fc1000080c080a007c0100aca8aeacfcec12a205cb94ff1cae35773bc6b3b54c9a50f69bee29877a055b737e29a863593ab5eec5e7dd9ae783a12035f979da77dd0a91c8fe19fb055")
    //     ids.signed_bytes_len = len(signed_bytes)
    //     unsigned_bytes = bytes.fromhex("02ef01058402321262850fd724715f8252089407d03a66c2fd7b9e60b4ae1177ca439d967884bb872386f26fc1000080c0")
    //     ids.unsigned_bytes_len = len(unsigned_bytes)

    //     signed_chunks = bytes_to_8_bytes_chunks_little(signed_bytes)
    //     ids.signed_len = len(signed_chunks)
    //     unsigned_chunks = bytes_to_8_bytes_chunks_little(unsigned_bytes)

    //     segments.write_arg(ids.signed_rlp, signed_chunks)
    //     segments.write_arg(ids.unsigned_rlp, unsigned_chunks)

    // %}