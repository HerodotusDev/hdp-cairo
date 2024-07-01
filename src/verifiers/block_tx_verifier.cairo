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
from src.types import TransactionProof, Header, ChainInfo
from src.memorizer import HeaderMemorizer, BlockTxMemorizer
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
// - block_tx_dict: A dictionary of transactions (memorizer).
func verify_n_block_tx_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    block_tx_dict: DictAccess*,
    header_dict: DictAccess*,
    pow2_array: felt*,
    chain_info: ChainInfo,
}(chain_id: felt, tx_proofs: TransactionProof*, tx_proofs_len: felt, index: felt) {
    alloc_locals;

    if (tx_proofs_len == index) {
        return ();
    }

    let tx_proof = tx_proofs[index];
    let (header_rlp) = HeaderMemorizer.get(chain_id=chain_id, block_number=tx_proof.block_number);
    let tx_root = HeaderDecoder.get_field(header_rlp, HeaderField.TRANSACTION_ROOT);

    let (rlp, _rlp_len) = verify_mpt_proof{
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

    let tx_index = chunk_to_felt_be(tx_proof.key.low);

    BlockTxMemorizer.add(
        chain_id=chain_id, block_number=tx_proof.block_number, key_low=tx_index, rlp=rlp
    );

    return verify_n_block_tx_proofs(
        chain_id=chain_id, tx_proofs=tx_proofs, tx_proofs_len=tx_proofs_len, index=index + 1
    );
}
