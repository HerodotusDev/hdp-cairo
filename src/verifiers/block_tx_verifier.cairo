from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.alloc import alloc
from packages.eth_essentials.lib.mpt import verify_mpt_proof
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.rlp import chunk_to_felt_be
from src.types import ChainInfo
from src.memorizers.evm import EvmHeaderMemorizer, EvmBlockTxMemorizer
from src.decoders.header_decoder import HeaderDecoder, HeaderField

// Verfies an array of transaction proofs with the headers stored in the memorizer.
// The verified transactions are then added to the memorizer.
func verify_block_tx_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    block_tx_dict: DictAccess*,
    header_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;

    local n_tx_proofs: felt;
    %{ ids.n_tx_proofs = len(program_input["proofs"]["transactions"]) %}

    verify_block_tx_proofs_inner(n_tx_proofs, 0);
    return ();
}

func verify_block_tx_proofs_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    block_tx_dict: DictAccess*,
    header_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_tx_proofs: felt, index: felt) {
    alloc_locals;

    if (n_tx_proofs == index) {
        return ();
    }

    local block_number: felt;
    local proof_len: felt;
    let (mpt_proof: felt**) = alloc();
    let (proof_bytes_len: felt*) = alloc();
    local key: Uint256;
    local key_leading_zeros: felt;
    %{
        transaction = program_input["proofs"]["transactions"][ids.index]
        ids.key_leading_zeros = count_leading_zero_nibbles_from_hex(transaction["key"])
        (key_low, key_high) = split_128(int(transaction["key"], 16))
        ids.key.low = key_low
        ids.key.high = key_high
        ids.block_number = transaction["block_number"]
        segments.write_arg(ids.mpt_proof, nested_hex_to_int_array(transaction["proof"]))
        segments.write_arg(ids.proof_bytes_len, transaction["proof_bytes_len"])
        ids.proof_len = len(transaction["proof"])
    %}

    let (header_rlp) = EvmHeaderMemorizer.get2(chain_id=chain_info.id, block_number=block_number);
    let tx_root = HeaderDecoder.get_field(header_rlp, HeaderField.TRANSACTION_ROOT);

    let (rlp, _rlp_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeros,
        root=tx_root,
        pow2_array=pow2_array,
    );

    let tx_index = chunk_to_felt_be(key.low);

    EvmBlockTxMemorizer.add(
        chain_id=chain_info.id, block_number=block_number, key_low=tx_index, rlp=rlp
    );

    return verify_block_tx_proofs_inner(n_tx_proofs=n_tx_proofs, index=index + 1);
}
