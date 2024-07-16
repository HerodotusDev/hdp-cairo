from starkware.cairo.common.uint256 import Uint256

struct ChainInfo {
    id: felt,
    id_bytes_len: felt,
    byzantium: felt,
}

struct MMRMeta {
    id: felt,
    root: felt,
    size: felt,
    peaks_len: felt,
    peaks: felt*,
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
    chain_id: felt,
    hash: Uint256,
    datalake_ptr: felt*,
    datalake_type: felt,
    aggregate_fn_id: felt,
    ctx_operator: felt,
    ctx_value: Uint256,
}
