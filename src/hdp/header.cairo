from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many

from src.libs.mmr import hash_subtree_path
from src.hdp.types import (
    Header,
    HeaderProof,
    MMRMeta,
)
from src.libs.block_header import extract_block_number_big, reverse_block_header_chunks
from src.hdp.memorizer import HeaderMemorizer

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
func verify_headers_inclusion{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    peaks_dict: DictAccess*,
    header_dict: DictAccess*
} (headers: Header*, mmr_size: felt, n_headers: felt, index: felt) {
    alloc_locals;
    if (index == n_headers) {
        return ();
    }

    // compute the hash of the header
    let (poseidon_hash) = poseidon_hash_many(
        n=headers[index].rlp_len, 
        elements=headers[index].rlp
    );

    %{
        poseidon_hash = ids.poseidon_hash
    %}

    // a header can be the right-most peak
    if (headers[index].proof.leaf_idx == mmr_size) {

        // instead of running an inclusion proof, we ensure its a known peak
        let (contains_peak) = dict_read{dict_ptr=peaks_dict}(poseidon_hash);
        assert contains_peak = 1;

        // add to memorizer
        let block_number = get_block_number(headers[index]);

        %{
            print(f"Writing: {ids.block_number} - Hash: {hex(ids.poseidon_hash)} - Index: {ids.index}")
        %}
        HeaderMemorizer.add(block_number=block_number, index=index);

        return verify_headers_inclusion(
            headers=headers,
            mmr_size=mmr_size,
            n_headers=n_headers,
            index=index + 1
        );
    } 
    tempvar hash = poseidon_hash;
    // compute the peak of the header
    let (computed_peak) = hash_subtree_path(
        element=poseidon_hash,
        height=0,
        position=headers[index].proof.leaf_idx,
        inclusion_proof=headers[index].proof.mmr_path,
        inclusion_proof_len=headers[index].proof.mmr_path_len
    );

    // ensure the peak is included in the peaks dict, which contains the peaks of the mmr_root
    let (contains_peak) = dict_read{dict_ptr=peaks_dict}(computed_peak);
    assert contains_peak = 1;

    // add to memorizer
    let block_number = get_block_number(headers[index]);
    HeaderMemorizer.add(block_number=block_number, index=index);


    return verify_headers_inclusion(
        headers=headers,
        mmr_size=mmr_size,
        n_headers=n_headers,
        index=index + 1
    );
}

func get_block_number{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (header: Header) -> felt {
    alloc_locals;
    // this is super inefficient, since we reverse all header chunks
    let (reversed, _n_felts) = reverse_block_header_chunks(header.bytes_len, header.rlp);
    let block_number = extract_block_number_big(reversed);
    return block_number;
}