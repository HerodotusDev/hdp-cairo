from src.hdp.tasks.aggregate_functions.sum import compute_sum
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256, uint256_signed_div_rem, uint256_add
from starkware.cairo.common.alloc import alloc

func compute_avg{
    range_check_ptr
}(values: Uint256*, values_len: felt) -> Uint256 {
    alloc_locals;
    let sum = compute_sum(values, values_len);
    let divisor = felt_to_uint256(values_len);

    let (result, remainder) = uint256_signed_div_rem(sum, divisor);
    local round_up: felt;

    // ToDo: Unsafe hint for now. Worst-case is incorrect rounding. 
    %{
        if ((ids.remainder.high * 2**128 + ids.remainder.low) / ids.values_len) >= 0.5:
            ids.round_up = 1
        else:
            ids.round_up = 0
    %}

    if(round_up == 1) {
        let (rounded, _carry) = uint256_add(result, Uint256(1, 0));
        return (rounded);
    }

    return (result);
}