from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from src.mpt import verify_mpt_proof
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.rlp import chunk_to_felt_be
from src.types import ChainInfo
from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField

// Verfies an array of receipt proofs with the headers stored in the memorizer.
// The verified receipts are then added to the memorizer.
func verify_block_receipt_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;

    local n_receipts: felt;
    %{ ids.n_receipts = len(batch["transaction_receipts"]) %}

    verify_block_receipt_proofs_inner(n_receipts, 0);
    return ();
}

func verify_block_receipt_proofs_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_receipts: felt, index: felt) {
    alloc_locals;

    if (n_receipts == index) {
        return ();
    }

    local block_number: felt;
    local proof_len: felt;
    let (mpt_proof: felt**) = alloc();
    let (proof_bytes_len: felt*) = alloc();
    local key: Uint256;
    local key_leading_zeros: felt;
    %{
        from tools.py.utils import split_128, count_leading_zero_nibbles_from_hex, hex_to_int_array, nested_hex_to_int_array

        transaction = batch["transaction_receipts"][ids.index]
        ids.key_leading_zeros = count_leading_zero_nibbles_from_hex(transaction["key"])
        (key_low, key_high) = split_128(int(transaction["key"], 16))
        ids.key.low = key_low
        ids.key.high = key_high
        ids.block_number = transaction["block_number"]
        segments.write_arg(ids.mpt_proof, nested_hex_to_int_array(transaction["proof"]))
        segments.write_arg(ids.proof_bytes_len, transaction["proof_bytes_len"])
        ids.proof_len = len(transaction["proof"])
    %}

    let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
    let (header_rlp) = EvmMemorizer.get(key=memorizer_key);
    let receipt_root = HeaderDecoder.get_field(header_rlp, HeaderField.RECEIPT_ROOT);

    let (rlp, rlp_bytes_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeros,
        root=receipt_root,
        pow2_array=pow2_array,
    );

    let receipt_index = chunk_to_felt_be(key.low);

    let memorizer_key = EvmHashParams.block_receipt(
        chain_id=chain_info.id, block_number=block_number, index=receipt_index
    );
    EvmMemorizer.add(key=memorizer_key, data=rlp);

    return verify_block_receipt_proofs_inner(n_receipts=n_receipts, index=index + 1);
}
