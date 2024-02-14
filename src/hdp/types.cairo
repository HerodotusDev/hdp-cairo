from starkware.cairo.common.uint256 import Uint256

struct HeaderProof {
    leaf_idx: felt,
    mmr_inclusion_proof_len: felt,
    rlp_encoded_header_len: felt,
    mmr_inclusion_proof: felt*,
    rlp_encoded_header: felt*,
}

struct Account {
	address: felt*,
	key: Uint256,
    proofs_len: felt,
	proofs: AccountProof*,
}

struct AccountProof {
    block_number: felt,
    proof_len: felt,
    proof_bytes_len: felt*,
    proof: felt**,
}

struct AccountState {
    values: felt*,
    values_len: felt,
}

struct MMRMeta {
    id: felt,
    root: felt,
	size: felt,
	peaks_len: felt,
	peaks: felt*,
}

struct AccountSlot   {
    account_id: felt,
    slot: felt*,
    key: Uint256,
    proofs_len: felt,
    proofs: AccountSlotProof*,
}

struct AccountSlotProof {
    block_number: felt,
    proof_len: felt,
    proof_bytes_len: felt*,
    proof: felt**,
}