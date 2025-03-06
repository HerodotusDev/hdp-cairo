from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from src.utils.mpt import verify_mpt_proof
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.utils.rlp import be_chunk_to_felt_be
from src.types import ChainInfo
from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField, HeaderKey
from starkware.cairo.common.registers import get_fp_and_pc

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

    tempvar n_receipts: felt = nondet %{ len(batch_evm.receipts) %};
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
}(n_receipts: felt, idx: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    if (n_receipts == idx) {
        return ();
    }

    %{ receipt = batch.receipts[ids.idx] %}

    local key: Uint256;
    %{ (ids.key.low, ids.key.high) = split_128(int(receipt.key, 16)) %}

    local key_leading_zeros: felt;
    %{ ids.key_leading_zeros = len(receipt.key.lstrip("0x")) - len(receipt.key.lstrip("0x").lstrip("0")) %}

    tempvar proof_len: felt = nondet %{ len(receipt.proof) %};
    tempvar block_number: felt = nondet %{ receipt.block_number %};

    let (proof_bytes_len: felt*) = alloc();
    %{ segments.write_arg(ids.proof_bytes_len, receipt.proof_bytes_len) %}

    let (mpt_proof: felt**) = alloc();
    %{ segments.write_arg(ids.mpt_proof, [int(x, 16) for x in receipt.proof]) %}

    local header_key: HeaderKey = HeaderKey(chain_id=chain_info.id, block_number=block_number);
    let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
    let (header_rlp) = EvmMemorizer.get(key=memorizer_key);
    let (receipt_root: Uint256*, _) = HeaderDecoder.get_field(header_rlp, HeaderField.RECEIPT_ROOT, &header_key);

    let (rlp, rlp_bytes_len) = verify_mpt_proof{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeros,
        root=Uint256(low=receipt_root.low, high=receipt_root.high),
        pow2_array=pow2_array,
    );

    let receipt_index = be_chunk_to_felt_be(key.low);

    let memorizer_key = EvmHashParams.block_receipt(
        chain_id=chain_info.id, block_number=block_number, index=receipt_index
    );
    EvmMemorizer.add(key=memorizer_key, data=rlp);

    return verify_block_receipt_proofs_inner(n_receipts=n_receipts, idx=idx + 1);
}
