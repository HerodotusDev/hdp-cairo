from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read

from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.uint256 import Uint256
from packages.eth_essentials.lib.utils import felt_divmod
from packages.eth_essentials.lib.mmr import hash_subtree_path
from src.types import MMRMeta, ChainInfo
from packages.eth_essentials.lib.block_header import (
    extract_block_number_big,
    reverse_block_header_chunks,
)
from src.memorizer import HeaderMemorizer
from src.decoders.header_decoder import HeaderDecoder

func verify_headers_inclusion{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    peaks_dict: DictAccess*,
    header_dict: DictAccess*,
    mmr_meta: MMRMeta,
    chain_info: ChainInfo,
}() {
    alloc_locals;

    local n_headers: felt;
    %{ ids.n_headers = len(program_input["headers"]) %}
    verify_headers_inclusion_inner(n_headers, 0);

    return ();
}

// Guard function that verifies the inclusion of headers in the MMR.
// It ensures:
// 1. The header hash is included in one of the peaks of the MMR.
// 2. The peaks dict contains the computed peak
// Since the computed mmr_root is an output, the verifier can ensure all header are included in the MMR by comparing this with a known root.
// Params:
// - header_proofs: The header proofs to verify
// - rlp_headers: The RLP encoded headers
// - mmr_inclusion_proofs: The MMR inclusion proofs
// - header_proofs_len: The length of the header proofs
// - mmr_size: The size of the MMR
func verify_headers_inclusion_inner{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    peaks_dict: DictAccess*,
    header_dict: DictAccess*,
    mmr_meta: MMRMeta,
    chain_info: ChainInfo,
}(n_headers: felt, index: felt) {
    alloc_locals;
    if (index == n_headers) {
        return ();
    }

    let (rlp) = alloc();
    local rlp_len: felt;
    local leaf_idx: felt;
    %{
        segments.write_arg(ids.rlp, hex_to_int_array(program_input["headers"][ids.index]["rlp"]))
        ids.rlp_len = len(program_input["headers"][ids.index]["rlp"])
        ids.leaf_idx = program_input["headers"][ids.index]["proof"]["leaf_idx"]
    %}

    // compute the hash of the header
    let (poseidon_hash) = poseidon_hash_many(n=rlp_len, elements=rlp);

    // a header can be the right-most peak
    if (leaf_idx == mmr_meta.size) {
        // instead of running an inclusion proof, we ensure its a known peak
        let (contains_peak) = dict_read{dict_ptr=peaks_dict}(poseidon_hash);
        assert contains_peak = 1;

        // add to memorizer
        let block_number = HeaderDecoder.get_block_number(rlp);
        HeaderMemorizer.add(chain_id=chain_info.id, block_number=block_number, rlp=rlp);

        return verify_headers_inclusion_inner(n_headers=n_headers, index=index + 1);
    }

    let (mmr_path) = alloc();
    local mmr_path_len: felt;
    %{
        segments.write_arg(ids.mmr_path, hex_to_int_array(program_input["headers"][ids.index]["proof"]["mmr_path"]))
        ids.mmr_path_len = len(program_input["headers"][ids.index]["proof"]["mmr_path"])
    %}

    // compute the peak of the header
    let (computed_peak) = hash_subtree_path(
        element=poseidon_hash,
        height=0,
        position=leaf_idx,
        inclusion_proof=mmr_path,
        inclusion_proof_len=mmr_path_len,
    );

    // ensure the peak is included in the peaks dict, which contains the peaks of the mmr_root
    let (contains_peak) = dict_read{dict_ptr=peaks_dict}(computed_peak);
    assert contains_peak = 1;

    // add to memorizer
    let block_number = HeaderDecoder.get_block_number(rlp);
    HeaderMemorizer.add(chain_id=chain_info.id, block_number=block_number, rlp=rlp);

    return verify_headers_inclusion_inner(n_headers=n_headers, index=index + 1);
}

// // def write_account(account_ptr, proofs_ptr, account):
// leading_zeroes = count_leading_zero_nibbles_from_hex(account["account_key"])
// (key_low, key_high) = split_128(int(account["account_key"], 16))

// memory[account_ptr._reference_value] = segments.gen_arg(hex_to_int_array(account["address"]))
// memory[account_ptr._reference_value + 1] = len(account["proofs"])
// memory[account_ptr._reference_value + 2] = key_low
// memory[account_ptr._reference_value + 3] = key_high
// memory[account_ptr._reference_value + 4] = leading_zeroes
// memory[account_ptr._reference_value + 5] = proofs_ptr._reference_value

// for proof in proofs:
//     memory[ptr._reference_value + offset] = proof["block_number"]
//     memory[ptr._reference_value + offset + 1] = len(proof["proof"])
//     memory[ptr._reference_value + offset + 2] = segments.gen_arg(proof["proof_bytes_len"])
//     memory[ptr._reference_value + offset + 3] = segments.gen_arg(nested_hex_to_int_array(proof["proof"]))
//     offset += 4
