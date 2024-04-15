from starkware.cairo.common.uint256 import Uint256

struct HeaderProof {
    leaf_idx: felt,
    mmr_path_len: felt,
    mmr_path: felt*,
}

struct Header {
    rlp: felt*,
    rlp_len: felt,
    bytes_len: felt,
    proof: HeaderProof,
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

struct AccountValues {
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

struct StorageItem {
    address: felt*,
    slot: felt*,
    key: Uint256,
    proofs_len: felt,
    proofs: StorageItemProof*,
}

struct StorageItemProof {
    block_number: felt,
    proof_len: felt,
    proof_bytes_len: felt*,
    proof: felt**,
}

struct Transaction {
    rlp: felt*,
    rlp_len: felt,
    bytes_len: felt,
    type: felt,
}

struct TransactionProof {
    block_number: felt,
    len: felt,
    bytes_len: felt*,
    proof: felt**,
    key: Uint256,
}

struct BlockSampledDataLake {
    block_range_start: felt,
    block_range_end: felt,
    increment: felt,
    property_type: felt,  // header=1, account=2, accountSlot=3
    properties: felt*,
    hash: Uint256,
}

struct BlockSampledComputationalTask {
    hash: Uint256,
    datalake: BlockSampledDataLake,
    aggregate_fn_id: felt,
    ctx_operator: felt,
    ctx_value: Uint256,
}
