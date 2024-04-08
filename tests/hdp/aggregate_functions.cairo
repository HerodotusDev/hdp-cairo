%builtins range_check bitwise
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from src.hdp.tasks.aggregate_functions.sum import compute_sum
from src.hdp.tasks.aggregate_functions.avg import compute_avg
from src.hdp.tasks.aggregate_functions.min_max import (
    uint256_min_be,
    uint256_max_be,
    uint256_min_le,
    uint256_max_le,
)

from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_reverse_endian
from starkware.cairo.common.alloc import alloc

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}() {
    avg_sum{range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr}();
    min_max{range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr}();
    return ();
}


func avg_sum{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
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

func min_max{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (local arr_be: felt*) = alloc();
    local res_min: Uint256;
    local res_max: Uint256;
    local len;

    %{
        from tools.py.utils import uint256_reverse_endian, from_uint256, split_128
        import random
        arr = [random.randint(0, 2**256-1) for _ in range(3)]
        arr.append(min(arr)+1)
        arr.append(max(arr)-1)
        res_min = split_128(min(arr))
        res_max = split_128(max(arr))
        arr_be = [split_128(x) for x in arr]
        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr+counter] = uint[0]
                memory[ptr+counter+1] = uint[1]
                counter += 2

        write_uint256_array(ids.arr_be, arr_be)
        ids.len = len(arr_be)
    %}
    let res = uint256_min_be(cast(arr_be, Uint256*), len);
    assert res.low = res_min.low;
    assert res.high = res_min.high;

    let res = uint256_max_be(cast(arr_be, Uint256*), len);
    assert res.low = res_max.low;
    assert res.high = res_max.high;

    let (local arr_le: felt*) = alloc();

    %{
        arr_le = [split_128(uint256_reverse_endian(from_uint256(x))) for x in arr_be]
        write_uint256_array(ids.arr_le, arr_le)
    %}

    let res = uint256_min_le(cast(arr_le, Uint256*), len);
    assert res.low = res_min.low;
    assert res.high = res_min.high;

    let res = uint256_max_le(cast(arr_le, Uint256*), len);
    assert res.low = res_max.low;
    assert res.high = res_max.high;

    return ();
}
