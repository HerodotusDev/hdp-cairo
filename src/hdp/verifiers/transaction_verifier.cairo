from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.cairo_secp.bigint import BigInt3, uint256_to_bigint
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import (
    recover_public_key,
    public_key_point_to_eth_address,
    verify_eth_signature,
)
from src.libs.mpt import verify_mpt_proof
from src.libs.utils import (
    pow2alloc128,
    write_felt_array_to_dict_keys,
    felt_divmod,
    felt_divmod_8,
    word_reverse_endian_64,
)
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
    extract_le_hash_from_le_64_chunks_array,
    assert_subset_in_key,
    extract_nibble_from_key,
)

from src.hdp.rlp import retrieve_from_rlp_list_via_idx
from src.hdp.utils import prepend_le_rlp_list_prefix
from src.hdp.types import TransactionProof, Transaction, Header, ChainInfo
from src.hdp.memorizer import HeaderMemorizer, TransactionMemorizer

from src.hdp.decoders.transaction_decoder import TransactionReader
from src.hdp.decoders.header_decoder import HeaderDecoder, HEADER_FIELD

func verify_n_transaction_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    transactions: Transaction*,
    transaction_dict: DictAccess*,
    headers: Header*,
    header_dict: DictAccess*,
    pow2_array: felt*,
    chain_info: ChainInfo,
}(tx_proofs: TransactionProof*, tx_proofs_len: felt, index: felt) {
    alloc_locals;

    if (tx_proofs_len == index) {
        return ();
    }

    let tx_proof = tx_proofs[index];

    let header = HeaderMemorizer.get(tx_proof.block_number);
    let tx_root = HeaderDecoder.get_field(header.rlp, HEADER_FIELD.TRANSACTION_ROOT);

    let (tx_item, tx_item_bytes_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
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

    let tx = init_tx_stuct{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, poseidon_ptr=poseidon_ptr
    }(tx_item=tx_item, tx_item_bytes_len=tx_item_bytes_len, block_number=tx_proof.block_number);

    TransactionMemorizer.add(tx_proof.block_number, tx_proof.key.low, index);
    assert transactions[index] = tx;

    return verify_n_transaction_proofs(
        tx_proofs=tx_proofs, tx_proofs_len=tx_proofs_len, index=index + 1
    );
}

func init_tx_stuct{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    chain_info: ChainInfo,
}(tx_item: felt*, tx_item_bytes_len: felt, block_number: felt) -> Transaction {
    alloc_locals;

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
    if (has_type_prefix == 1) {
        assert [range_check_ptr] = 0x3 - first_byte;  // current the highest tx type is 3
        assert [range_check_ptr + 1] = 0xff - second_byte;
        assert [range_check_ptr + 2] = second_byte - 0xf7;
        tempvar range_check_ptr = range_check_ptr + 3;

        assert tx_type = first_byte;
        let len_len = second_byte - 0xf7;
        assert tx_start_offset = 2 + len_len;  // type + prefix + len_len
    } else {
        assert tx_type = 0;

        let len_len = first_byte - 0xf7;
        assert tx_start_offset = 1 + len_len;

        assert [range_check_ptr ] = 0xff - first_byte;
        assert [range_check_ptr + 1] = first_byte - 0xf7;
        assert [range_check_ptr + 2] = 7 - tx_start_offset;
        tempvar range_check_ptr = range_check_ptr + 3;
    }

    let tx_bytes_len = tx_item_bytes_len - tx_start_offset;
    // retrieve the encoded tx rlp fields
    let (tx_rlp, tx_rlp_len) = extract_n_bytes_from_le_64_chunks_array(
        array=tx_item,
        start_word=0,
        start_offset=tx_start_offset,
        n_bytes=tx_bytes_len,
        pow2_array=pow2_array,
    );

    let tx = Transaction(rlp=tx_rlp, rlp_len=tx_rlp_len, bytes_len=tx_bytes_len, type=tx_type);

    return (tx);
}
