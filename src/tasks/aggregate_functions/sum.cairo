from src.tasks.fetch_trait import (
    FetchTrait,
    FetchTraitBlockSampledDatalake,
    FetchTraitTransactionDatalake,
)
from starkware.cairo.common.uint256 import Uint256
from packages.eth_essentials.lib.utils import uint256_add, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location
from src.datalakes.block_sampled_datalake import (
    fetch_header_data_points,
    fetch_account_data_points,
    fetch_storage_data_points,
)
from src.datalakes.txs_in_block_datalake import fetch_tx_data_points
from starkware.cairo.common.registers import get_fp_and_pc

func get_fetch_trait() -> FetchTrait {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let (fetch_header_data_points_ptr) = get_label_location(fetch_header_data_points);
    let (fetch_account_data_points_ptr) = get_label_location(fetch_account_data_points);
    let (fetch_storage_data_points_ptr) = get_label_location(fetch_storage_data_points);
    let (fetch_tx_data_points_ptr) = get_label_location(fetch_tx_data_points);

    local block_sampled_datalake: FetchTraitBlockSampledDatalake = FetchTraitBlockSampledDatalake(
        fetch_header_data_points_ptr, fetch_account_data_points_ptr, fetch_storage_data_points_ptr
    );

    local transaction_datalake: FetchTraitTransactionDatalake = FetchTraitTransactionDatalake(
        fetch_tx_data_points_ptr
    );

    return (
        FetchTrait(
            block_sampled_datalake=&block_sampled_datalake,
            transaction_datalake=&transaction_datalake,
        )
    );
}

func compute_sum{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    values_le: Uint256*, values_len: felt
) -> Uint256 {
    alloc_locals;
    if (values_len == 0) {
        return (Uint256(0, 0));
    }

    let sum_of_rest = compute_sum(values_le=values_le + Uint256.SIZE, values_len=values_len - 1);

    let (value) = uint256_reverse_endian(values_le[0]);
    let (result, _carry) = uint256_add(value, sum_of_rest);

    return (result);
}
