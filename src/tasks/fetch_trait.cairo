struct FetchTrait {
    block_sampled_datalake: FetchTraitBlockSampledDatalake*,
    transaction_datalake: FetchTraitTransactionDatalake*,
}

struct FetchTraitBlockSampledDatalake {
    fetch_header_data_points_ptr: felt*,
    fetch_account_data_points_ptr: felt*,
    fetch_storage_data_points_ptr: felt*,
}

struct FetchTraitTransactionDatalake {
    fetch_tx_data_points_ptr: felt*,
}
