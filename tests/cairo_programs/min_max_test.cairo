%builtins range_check

from starkware.cairo.common.alloc import alloc

from src.libs.utils import uint256_min_be, uint256_max_be, Uint256

func main{range_check_ptr}() {
    alloc_locals;
    let (local arr: felt*) = alloc();
    local len;

    %{
        arr = [(1, 0), (2, 2), (2, 3)]
        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr+counter] = uint[0]
                memory[ptr+counter+1] = uint[1]
                counter += 2

        write_uint256_array(ids.arr, arr)
        ids.len = len(arr)
    %}
    let res = uint256_min_be(cast(arr, Uint256*), len);
    assert res.low = 1;
    assert res.high = 0;

    let res = uint256_max_be(cast(arr, Uint256*), len);
    assert res.low = 2;
    assert res.high = 3;
    return ();
}
