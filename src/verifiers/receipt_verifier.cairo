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
from src.types import ReceiptProof, Receipt, Header
from src.memorizer import HeaderMemorizer, ReceiptMemorizer
from src.decoders.header_decoder import HeaderDecoder, HeaderField
from src.verifiers.transaction_verifier import derive_tx_or_receipt_payload

// Verfies an array of receipt proofs with the headers stored in the memorizer.
// The verified receipts are then added to the memorizer.
// Inputs:
// - receipt_proofs: An array of receipt proofs.
// - receipt_proofs_len: The length of the array.
// - index: The index of the current receipt proof to verify.
// Outputs:
// The outputs are added to the implicit args.
// - receipts: An array of receipts.
// - receipt_dict: A dictionary of receipts (memorizer).
func verify_n_receipt_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    receipts: Receipt*,
    receipt_dict: DictAccess*,
    headers: Header*,
    header_dict: DictAccess*,
    pow2_array: felt*,
}(receipt_proofs: ReceiptProof*, receipt_proofs_len: felt, index: felt) {
    alloc_locals;

    if (receipt_proofs_len == index) {
        return ();
    }

    let receipt_proof = receipt_proofs[index];
    let header = HeaderMemorizer.get(receipt_proof.block_number);
    let receipt_root = HeaderDecoder.get_field(header.rlp, HeaderField.RECEIPT_ROOT);

    let (rlp, rlp_bytes_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(
        mpt_proof=receipt_proof.proof,
        mpt_proof_bytes_len=receipt_proof.bytes_len,
        mpt_proof_len=receipt_proof.len,
        key_be=receipt_proof.key,
        key_be_leading_zeroes_nibbles=receipt_proof.key_leading_zeros,
        root=receipt_root,
        pow2_array=pow2_array,
    );

    let (rlp, rlp_len, bytes_len, tx_type) = derive_tx_or_receipt_payload(
        item=rlp, item_bytes_len=rlp_bytes_len
    );
    let receipt = Receipt(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=tx_type,
        block_number=receipt_proof.block_number,
    );

    // decode receipt-index from rlp-encoded key
    assert receipt_proof.key.high = 0;  // sanity check
    let receipt_index = chunk_to_felt_be(receipt_proof.key.low);

    ReceiptMemorizer.add(receipt_proof.block_number, receipt_index, index);

    assert receipts[index] = receipt;

    return verify_n_receipt_proofs(
        receipt_proofs=receipt_proofs, receipt_proofs_len=receipt_proofs_len, index=index + 1
    );
}
