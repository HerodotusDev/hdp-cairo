from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many

from src.libs.mmr import hash_subtree_path
from src.hdp.types import (
    HeaderProof,
    MMRMeta,
)

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
    pow2_array: felt*,
    peaks_dict: DictAccess*,
} (header_proofs: HeaderProof*, header_proofs_len: felt, mmr_size: felt) {
    if (header_proofs_len == 0) {
        return ();
    }
    let header_proof_idx = header_proofs_len - 1;

    // compute the hash of the header
    let (poseidon_hash) = poseidon_hash_many(
        n=header_proofs[header_proof_idx].rlp_encoded_header_len, 
        elements=header_proofs[header_proof_idx].rlp_encoded_header
    );

    // a header can be the right-most peak
    if (header_proofs[header_proof_idx].leaf_idx == mmr_size) {

        // instead of running an inclusion proof, we ensure its a known peak
        let (contains_peak) = dict_read{dict_ptr=peaks_dict}(poseidon_hash);
        assert contains_peak = 1;

        return verify_headers_inclusion(
            header_proofs=header_proofs,
            header_proofs_len=header_proof_idx,
            mmr_size=mmr_size
        );
    } 
    
    // compute the peak of the header
    let (computed_peak) = hash_subtree_path(
        element=poseidon_hash,
        height=0,
        position=header_proofs[header_proof_idx].leaf_idx,
        inclusion_proof=header_proofs[header_proof_idx].mmr_inclusion_proof,
        inclusion_proof_len=header_proofs[header_proof_idx].mmr_inclusion_proof_len
    );

    // ensure the peak is included in the peaks dict, which contains the peaks of the mmr_root
    let (contains_peak) = dict_read{dict_ptr=peaks_dict}(computed_peak);
    assert contains_peak = 1;

    return verify_headers_inclusion(
        header_proofs=header_proofs,
        header_proofs_len=header_proof_idx,
        mmr_size=mmr_size
    );
}