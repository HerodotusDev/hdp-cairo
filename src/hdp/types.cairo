from starkware.cairo.common.uint256 import Uint256

struct HeaderProof {
    leaf_idx: felt,
    mmr_path_len: felt,
    mmr_path: felt*,
}

struct Header {
    rlp_len: felt,
    bytes_len: felt,
    leaf_idx: felt,
    mmr_path_len: felt,
    rlp: felt*,
    mmr_path: felt*,
    // proof: HeaderProof,
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
    address: felt*,
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

struct SlotState {
    low: felt,
    high: felt,
}

struct BlockSampledDataLake {
    block_range_start: felt,
    block_range_end: felt,
    increment: felt,
    property_type: felt, // header=1, account=2, accountSlot=3
    properties: felt*,
    hash: Uint256,
}

struct BlockSampledComputationalTask {
    aggregate_fn_id: felt, // avg=0, sum=1, min=2, max=3
    // aggregateFnCtx: felt*,
    hash: Uint256,
    datalake: BlockSampledDataLake,
}