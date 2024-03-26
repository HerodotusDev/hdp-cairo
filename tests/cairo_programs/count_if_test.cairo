%builtins range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from src.hdp.tasks.aggregate_functions.count_if import count_if
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (local arrs: felt**) = alloc();
    let (local ops: felt*) = alloc();
    let (local values: felt*) = alloc();
    let (local expected: felt*) = alloc();
    local n_tests = 100;
    %{
        from tools.py.utils import uint256_reverse_endian, from_uint256, split_128, flatten
        import random
        from enum import Enum, auto
        random.seed(0)

        class COUNTIFOP(Enum):
            EQ = 0
            NEQ = 1
            GT = 2
            GE = 3
            LT = 4
            LE = 5

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
        for i in range(ids.n_tests):
            op = random.choice(list(COUNTIFOP))
            ops.append(op.value)
            arr=[random.randint(0, 32) for _ in range(64)]
            arrs.append(flatten([split_128(uint256_reverse_endian(x)) for x in arr]))
            value = random.randint(0, 32)
            values.extend(split_128(value))
            expected.append(count_if(arr, op, value))

        segments.write_arg(ids.arrs, arrs)
        segments.write_arg(ids.ops, ops)
        segments.write_arg(ids.values, values)
        segments.write_arg(ids.expected, expected)
    %}
    test_count_if(cast(arrs, Uint256**), ops, cast(values, Uint256*), expected, 0, n_tests);
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
    let (res) = count_if(arr, 64, op, value);
    %{ print(f"{ids.res=}, {ids.expected=}") %}
    assert res = expected;
    return ();
}
