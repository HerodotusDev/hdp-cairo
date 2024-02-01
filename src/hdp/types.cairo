struct HeaderProof {
    mmr_id: felt,
    mmr_inclusion_proof: felt*,
    mmr_inclusion_proof_len: felt,
    leaf_ix: felt,
    rlp_encoded_header: felt,
}

struct AccountProof {
	block: felt,
	account: felt*,
	account_len: felt,
	mpt_proof: felt**,
	mpt_proof_len: felt,
}

