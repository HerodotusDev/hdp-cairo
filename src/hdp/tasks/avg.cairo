from src.hdp.tasks.sum import compute_sum
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256, uint256_signed_div_rem

func compute_avg{
    range_check_ptr
}(values: Uint256*, values_len: felt) -> Uint256 {
    let sum = compute_sum(values, values_len);
    let divisor = felt_to_uint256(values_len);

    let (result, _rem) = uint256_signed_div_rem(sum, divisor);
    return (result);
}


