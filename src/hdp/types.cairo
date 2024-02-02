struct HeaderProof {
    mmr_id: felt,
    leaf_idx: felt,
    mmr_inclusion_proof_len: felt,
    rlp_encoded_header_len: felt,
    // mmr_inclusion_proof: felt*,
    // rlp_encoded_header: felt*,
}

struct AccountProof {
	block: felt,
	account: felt*,
	account_len: felt,
	mpt_proof: felt**,
	mpt_proof_len: felt,
}

struct MMRMeta {
    mmr_root: felt, // public (asserted in the output_ptr)
	mmr_size: felt,
	// mmr_peaks: felt*,
	mmr_peaks_len: felt,
}