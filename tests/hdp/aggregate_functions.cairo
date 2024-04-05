%builtins range_check bitwise
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from src.hdp.tasks.aggregate_functions.sum import compute_sum
from src.hdp.tasks.aggregate_functions.avg import compute_avg

from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_reverse_endian
from starkware.cairo.common.alloc import alloc

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let (round_down_values_le: Uint256*) = alloc();
    let (v0) = uint256_reverse_endian(Uint256(low=2, high=0));
    let (v1) = uint256_reverse_endian(Uint256(low=2, high=0));
    let (v2) = uint256_reverse_endian(Uint256(low=3, high=0));

    assert round_down_values_le[0] = v0;
    assert round_down_values_le[1] = v1;
    assert round_down_values_le[2] = v2;

    let expected_sum = Uint256(low=7, high=0);
    let expected_avg = Uint256(low=2, high=0); // sum is 7, avg is 7/3 = 2.333 -> 2

    let sum = compute_sum(values_le=round_down_values_le, values_len=3);
    let (eq) = uint256_eq(a=sum, b=expected_sum);
    assert eq = 1;

    let avg_round_down = compute_avg(values=round_down_values_le, values_len=3);
    let (eq) = uint256_eq(a=avg_round_down, b=expected_avg);
    assert eq = 1;

    let (round_up_values_le: Uint256*) = alloc();

    let (v0) = uint256_reverse_endian(Uint256(low=2, high=0));
    let (v1) = uint256_reverse_endian(Uint256(low=2, high=0));
    let (v2) = uint256_reverse_endian(Uint256(low=3, high=0));
    let (v3) = uint256_reverse_endian(Uint256(low=3, high=0));

    assert round_up_values_le[0] = v0;
    assert round_up_values_le[1] = v1;
    assert round_up_values_le[2] = v2;
    assert round_up_values_le[3] = v3;

    let expected_avg_up = Uint256(low=3, high=0); // sum is 10, avg is 10/4 = 2.5 -> 3
    let avg_round_up = compute_avg(values=round_up_values_le, values_len=4);
    let (eq) = uint256_eq(a=avg_round_up, b=expected_avg_up);
    assert eq = 1;

    return ();
}