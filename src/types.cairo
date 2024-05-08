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
    proofs_len: felt,
    key: Uint256,
    key_leading_zeros: felt,
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

struct ChainInfo {
    id: felt,
    id_bytes_len: felt,
    eip155_activation: felt,
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
    proofs_len: felt,
    key: Uint256,
    key_leading_zeros: felt,
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
    key_leading_zeros: felt,
}

struct BlockSampledDataLake {
    block_range_start: felt,
    block_range_end: felt,
    increment: felt,
    property_type: felt,  // header=1, account=2, accountSlot=3
    properties: felt*,
}

struct TransactionsInBlockDatalake {
    target_block: felt,
    start_index: felt,
    end_index: felt,
    increment: felt,
    type: felt,  // 1=transaction, 2=receipt
    included_types: felt*,
    sampled_property: felt,
}

struct ComputationalTask {
    hash: Uint256,
    datalake_ptr: felt*,
    datalake_type: felt,
    aggregate_fn_id: felt,
    ctx_operator: felt,
    ctx_value: Uint256,
}
