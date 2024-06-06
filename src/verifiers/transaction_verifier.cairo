from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from packages.eth_essentials.lib.mpt import verify_mpt_proof
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.rlp import chunk_to_felt_be
from src.types import TransactionProof, Transaction, Header, ChainInfo
from src.memorizer import HeaderMemorizer, TransactionMemorizer
from src.decoders.header_decoder import HeaderDecoder, HeaderField

// Verfies an array of transaction proofs with the headers stored in the memorizer.
// The verified transactions are then added to the memorizer.
// Inputs:
// - tx_proofs: An array of transaction proofs.
// - tx_proofs_len: The length of the array.
// - index: The index of the current transaction proof to verify.
// Outputs:
// The outputs are added to the implicit args.
// - transactions: An array of transactions.
// - transaction_dict: A dictionary of transactions (memorizer).
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
    let tx_root = HeaderDecoder.get_field(header.rlp, HeaderField.TRANSACTION_ROOT);

    let (tx_item, tx_item_bytes_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(
        mpt_proof=tx_proof.proof,
        mpt_proof_bytes_len=tx_proof.bytes_len,
        mpt_proof_len=tx_proof.len,
        key_be=tx_proof.key,
        key_be_leading_zeroes_nibbles=tx_proof.key_leading_zeros,
        root=tx_root,
        pow2_array=pow2_array,
    );

    let tx = init_tx_stuct{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, poseidon_ptr=poseidon_ptr
    }(tx_item=tx_item, tx_item_bytes_len=tx_item_bytes_len);

    // decode tx-index from rlp-encoded key
    assert tx_proof.key.high = 0;  // sanity check
    let tx_index = chunk_to_felt_be(tx_proof.key.low);

    TransactionMemorizer.add(tx_proof.block_number, tx_index, index);
    assert transactions[index] = tx;

    return verify_n_transaction_proofs(
        tx_proofs=tx_proofs, tx_proofs_len=tx_proofs_len, index=index + 1
    );
}

// Derives a TX type and initializes a Transaction struct.
// Inputs:
// - tx_item: The RLP-encoded transaction.
// - tx_item_bytes_len: The length of the RLP-encoded transaction.
// Outputs:
// - Transaction struct.
func init_tx_stuct{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, poseidon_ptr: PoseidonBuiltin*, pow2_array: felt*
}(tx_item: felt*, tx_item_bytes_len: felt) -> Transaction {
    alloc_locals;

    let first_byte = extract_byte_at_pos(tx_item[0], 0, pow2_array);
    let second_byte = extract_byte_at_pos(tx_item[0], 1, pow2_array);

    local has_type_prefix: felt;
    %{
        # typed transactions have a type prefix in this range [1, 3]
        if 0x0 < ids.first_byte < 0x04:
            ids.has_type_prefix = 1
        else:
            ids.has_type_prefix = 0
    %}

    local tx_type: felt;
    local tx_start_offset: felt;
    if (has_type_prefix == 1) {
        assert [range_check_ptr] = 0x3 - first_byte;
        assert [range_check_ptr + 1] = 0xff - second_byte;
        assert [range_check_ptr + 2] = second_byte - 0xf7;

        assert tx_type = first_byte;
        let len_len = second_byte - 0xf7;
        assert tx_start_offset = 2 + len_len;  // type + prefix + len_len
        assert [range_check_ptr + 3] = 7 - tx_start_offset;
        tempvar range_check_ptr = range_check_ptr + 4;
    } else {
        assert tx_type = 0;

        let len_len = first_byte - 0xf7;
        assert tx_start_offset = 1 + len_len;
        // Legacy transactions must start with long list prefix
        assert [range_check_ptr] = 0xff - first_byte;
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
