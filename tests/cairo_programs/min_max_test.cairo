%builtins range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from src.hdp.tasks.aggregate_functions.min_max import (
    uint256_min_be,
    uint256_max_be,
    uint256_min_le,
    uint256_max_le,
)
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
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
