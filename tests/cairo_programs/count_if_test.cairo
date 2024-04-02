%builtins range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from src.hdp.tasks.aggregate_functions.count_if import count_if
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256

const TEST_ARRAY_SIZE = 16;
const N_TESTS = 1000;
func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
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
