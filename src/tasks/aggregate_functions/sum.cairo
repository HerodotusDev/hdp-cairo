from src.tasks.fetch_trait import FetchTrait
from starkware.cairo.common.uint256 import Uint256
from packages.eth_essentials.lib.utils import uint256_add, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location
from src.datalakes.block_sampled_datalake import (
    fetch_header_data_points,
    fetch_account_data_points,
    fetch_storage_data_points,
)

func get_fetch_trait() -> FetchTrait {
    let (fetch_header_data_points_ptr) = get_label_location(fetch_header_data_points);
    let (fetch_account_data_points_ptr) = get_label_location(fetch_account_data_points);
    let (fetch_storage_data_points_ptr) = get_label_location(fetch_storage_data_points);

    return (
        FetchTrait(
            fetch_header_data_points_ptr,
            fetch_account_data_points_ptr,
            fetch_storage_data_points_ptr,
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
