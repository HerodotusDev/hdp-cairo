%builtins pedersen range_check bitwise poseidon

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin, PoseidonBuiltin

from src.tasks.aggregate_functions.sum import compute_sum
from src.tasks.aggregate_functions.slr import compute_slr
from src.tasks.aggregate_functions.avg import compute_avg
from src.tasks.aggregate_functions.min_max import (
    uint256_min_be,
    uint256_max_be,
    uint256_min_le,
    uint256_max_le,
)
from src.tasks.aggregate_functions.count_if import count_if

from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_reverse_endian
from starkware.cairo.common.alloc import alloc

func main{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    avg_sum{range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr}();
    min_max{range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr}();
    count_if_main{range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr}();
    slr_main{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        poseidon_ptr=poseidon_ptr,
    }();
    return ();
}

func avg_sum{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (round_down_values_le: Uint256*) = alloc();
    let (v0) = uint256_reverse_endian(Uint256(low=2, high=0));
    let (v1) = uint256_reverse_endian(Uint256(low=2, high=0));
    let (v2) = uint256_reverse_endian(Uint256(low=3, high=0));

    assert round_down_values_le[0] = v0;
    assert round_down_values_le[1] = v1;
    assert round_down_values_le[2] = v2;

    let expected_sum = Uint256(low=7, high=0);
    let expected_avg = Uint256(low=2, high=0);  // sum is 7, avg is 7/3 = 2.333 -> 2

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

    let expected_avg_up = Uint256(low=3, high=0);  // sum is 10, avg is 10/4 = 2.5 -> 3
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

const TEST_ARRAY_SIZE = 16;
const N_TESTS = 1000;
func count_if_main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (local arrs: felt**) = alloc();
    let (local ops: felt*) = alloc();
    let (local values: felt*) = alloc();
    let (local expected: felt*) = alloc();
    %{
        from tools.py.utils import uint256_reverse_endian, from_uint256, split_128, flatten
        import random
        from enum import Enum, auto
        random.seed(0)

        class COUNTIFOP(Enum):
            EQ = 1
            NEQ = 2
            GT = 3
            GE = 4
            LT = 5
            LE = 6

        def count_if(array:list, op:COUNTIFOP, value) -> int:
            counter = 0
            for uint in array:
                if op == COUNTIFOP.EQ:
                    if uint == value:
                        counter += 1
                elif op == COUNTIFOP.NEQ:
                    if uint != value:
                        counter += 1
                elif op == COUNTIFOP.GT:
                    if uint > value:
                        counter += 1
                elif op == COUNTIFOP.GE:
                    if uint >= value:
                        counter += 1
                elif op == COUNTIFOP.LT:
                    if uint < value:
                        counter += 1
                elif op == COUNTIFOP.LE:
                    if uint <= value:
                        counter += 1
            return counter

        arrs = []
        ops = []
        values = []
        expected = []
        for i in range(ids.N_TESTS):
            op = random.choice(list(COUNTIFOP))
            ops.append(op.value)
            if i % 2 == 0:
                arr=[random.randint(0, 8) for _ in range(ids.TEST_ARRAY_SIZE)]
                value = random.randint(0, 8)

            else:
                if i % 3 == 0:
                    arr=[random.randint(2**128, 2**256-1) for _ in range(ids.TEST_ARRAY_SIZE)]
                    value = random.randint(2**128, 2**256-1)
                else:
                    arr=[random.randint(0, 2**256-1) for _ in range(ids.TEST_ARRAY_SIZE)]
                    value = random.choice(arr)

            arrs.append(flatten([split_128(uint256_reverse_endian(x)) for x in arr]))
            values.extend(split_128(value))
            expected.append(count_if(arr, op, value))

        segments.write_arg(ids.arrs, arrs)
        segments.write_arg(ids.ops, ops)
        segments.write_arg(ids.values, values)
        segments.write_arg(ids.expected, expected)
    %}
    test_count_if(cast(arrs, Uint256**), ops, cast(values, Uint256*), expected, 0, N_TESTS);
    return ();
}

func test_count_if{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    arrs: Uint256**, ops: felt*, values: Uint256*, expected: felt*, index: felt, len: felt
) {
    if (index == len) {
        return ();
    } else {
        test_count_if_inner(arrs[index], ops[index], values[index], expected[index]);
        return test_count_if(arrs, ops, values, expected, index + 1, len);
    }
}

func test_count_if_inner{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    arr: Uint256*, op: felt, value: Uint256, expected: felt
) {
    let (res) = count_if(arr, TEST_ARRAY_SIZE, op, value);
    // %{ print(f"{ids.res=}, {ids.expected=}") %}
    assert res = expected;
    return ();
}

func slr_main{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    let (local array: felt*) = alloc();
    %{ segments.write_arg(ids.array, [2, 1, 0, 2, 0, 2, 3, 0, 5, 0, 0, 10, 0, 1, 0]) %}

    %{
        hdp_bootloader_input = {
            "task": {
                "type": "CairoSierra",
                "path": "build/compiled_cairo_files/simple_linear_regression.sierra.json",
                "use_poseidon": True
            },
            "single_page": True
        }
    %}

    let values: Uint256* = cast(array, Uint256*);

    let output_hash = compute_slr{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        poseidon_ptr=poseidon_ptr,
    }(values=values, values_len=15);

    local expected_hash: felt;

    %{
        from starkware.cairo.lang.vm.crypto import poseidon_hash
        from starkware.cairo.common.hash_state import compute_hash_on_elements

        ids.expected_hash = compute_hash_on_elements(data=[
            0x0,
            0x15,
            0x0,
            0x1,
            0x0,
        ], hash_func=poseidon_hash)
    %}

    assert output_hash.low = expected_hash;

    return ();
}
