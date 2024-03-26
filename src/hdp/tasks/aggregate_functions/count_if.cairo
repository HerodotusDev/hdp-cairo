from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from starkware.cairo.common.uint256 import (
    Uint256,
    SHIFT,
    word_reverse_endian,
    uint256_reverse_endian,
)

const TRUE = 1;
const FALSE = 0;

namespace COUNT_IF {
    const EQ = 0;  // ==
    const NEQ = 1;  // !=
    const GT = 2;  // >
    const GE = 3;  // >=
    const LT = 4;  // <
    const LE = 5;  // <=
}

// Takes an array of Uint256 values and returns the number of elements that satisfy the condition.
// Params :
// -array: The array of Uint256 values (represented in Little endian)
// -len: The length of the array.
// -op: The operation to perform. One of COUNT_IF.EQ, COUNT_IF.NEQ, COUNT_IF.GT, COUNT_IF.GE, COUNT_IF.LT, COUNT_IF.LE.
// -value: The Uint256 value to compare (big endian)
// Returns:
// -res: The number of elements that satisfy the condition.
// If the OP is not supported, or the array is empty, returns -1.
// Assumptions :
// - The array has valid Uint256 values in little endian bytes representation.
// - The value to compare to is in big endian representation.
func count_if{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    array: Uint256*, len: felt, op: felt, value: Uint256
) -> (res: felt) {
    alloc_locals;
    %{
        from tools.py.utils import uint256_reverse_endian 
        print(f"{COUNTIFOP(ids.op)}")
        print(f"value={ids.value.low + 2**128* ids.value.high}")
    %}
    if (op == COUNT_IF.EQ) {
        let res = count_if_eq(array, len, value);
        return res;
    }
    if (op == COUNT_IF.NEQ) {
        let res = count_if_neq(array, len, value);
        return res;
    }
    if (op == COUNT_IF.GT) {
        return count_if_gt(array, len, value);
    }
    if (op == COUNT_IF.GE) {
        return count_if_ge(array, len, value);
    }
    if (op == COUNT_IF.LT) {
        return count_if_lt(array, len, value);
    }
    if (op == COUNT_IF.LE) {
        return count_if_le(array, len, value);
    }

    return (res=-1);
}

func count_if_eq{bitwise_ptr: BitwiseBuiltin*}(array: Uint256*, len: felt, value: Uint256) -> (
    res: felt
) {
    if (len == 0) {
        return (res=-1);
    }
    alloc_locals;
    let (local val_le: Uint256) = uint256_reverse_endian(value);
    local bitwise_ptr: BitwiseBuiltin* = bitwise_ptr;

    %{ index=0 %}
    tempvar count = 0;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    %{ index+=1 %}
    if ([arr] == val_le.low) {
        if ([arr + 1] == val_le.high) {
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        [ap] = count, ap++;
        [ap] = arr + Uint256.SIZE, ap++;
        jmp loop;
    }

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let count = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return (res=count);
}

// Computes sum ( arr[i] != value)
// Assumptions :
// Array is in little endian.
// Value is in big endian.
// Comparison is made in big endian.
func count_if_neq{bitwise_ptr: BitwiseBuiltin*}(array: Uint256*, len: felt, value: Uint256) -> (
    res: felt
) {
    if (len == 0) {
        return (res=-1);
    }
    alloc_locals;

    let (local val_le: Uint256) = uint256_reverse_endian(value);
    local bitwise_ptr: BitwiseBuiltin* = bitwise_ptr;
    %{ index=0 %}

    tempvar count = 0;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    %{ index+=1 %}
    if ([arr] == val_le.low) {
        if ([arr + 1] == val_le.high) {
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        [ap] = count + 1, ap++;
        [ap] = arr + Uint256.SIZE, ap++;
        jmp loop;
    }

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let count = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return (res=count);
}

// Computes sum (arr[i] > value)
// Assumptions :
// Array is in little endian.
// Value is in big endian.
// Comparison is made in big endian.
func count_if_gt{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    array: Uint256*, len: felt, value: Uint256
) -> (res: felt) {
    if (len == 0) {
        return (res=-1);
    }
    alloc_locals;

    let (local val_le: Uint256) = uint256_reverse_endian(value);
    %{ index=0 %}
    tempvar range_check_ptr = range_check_ptr;
    tempvar bitwise_ptr = bitwise_ptr;
    tempvar count = 0;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    %{ index+=1 %}
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) > ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;

    if ([ap - 1] != FALSE) {
        // Assert array[i] > value <=> value < array[i] <=> value + 1 <= array[i]
        let val_low = val_low + 1;
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    }

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let count = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return (res=count);
}

// Computes sum ( arr[i] >= value)
// Assumptions :
// Array is in little endian.
// Value is in big endian.
// Comparison is made in big endian.
func count_if_ge{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    array: Uint256*, len: felt, value: Uint256
) -> (res: felt) {
    if (len == 0) {
        return (res=-1);
    }
    alloc_locals;

    let (local val_le: Uint256) = uint256_reverse_endian(value);

    %{ print(f"{ids.val_le.low=}, {ids.val_le.high=}") %}
    %{ index=0 %}
    tempvar range_check_ptr = range_check_ptr;
    tempvar bitwise_ptr = bitwise_ptr;
    tempvar count = 0;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let range_check_ptr = [ap - 4];
    let bitwise_ptr = cast([ap - 3], BitwiseBuiltin*);
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    %{
        #print(f"{index=}/{ids.len}, {ids.count=}")
        index+=1
    %}
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) >= ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;
    if ([ap - 1] != FALSE) {
        // Assert array[i] >= value
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    }

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let count = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;

    return (res=count);
}

// Computes sum (arr[i] < value)
// Assumptions :
// Array is in little endian.
// Value is in big endian.
// Comparison is made in big endian.
func count_if_lt{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    array: Uint256*, len: felt, value: Uint256
) -> (res: felt) {
    if (len == 0) {
        return (res=-1);
    }
    alloc_locals;

    let (local val_le: Uint256) = uint256_reverse_endian(Uint256(value.low + 1, value.high));
    %{ index=0 %}
    tempvar range_check_ptr = range_check_ptr;
    tempvar bitwise_ptr = bitwise_ptr;
    tempvar count = 0;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    %{
        #print(f"{index=}/{ids.len}, {ids.count=}")
        index+=1
    %}
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) < ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;

    if ([ap - 1] != FALSE) {
        // Assert array[i] < value <=> value > array[i] <=> value >= array[i] + 1
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    }

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let count = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return (res=count);
}

// Computes sum (arr[i] <= value)
// Assumptions :
// Array is in little endian.
// Value is in big endian.
// Comparison is made in big endian.
func count_if_le{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    array: Uint256*, len: felt, value: Uint256
) -> (res: felt) {
    if (len == 0) {
        return (res=-1);
    }
    alloc_locals;

    let (local val_le: Uint256) = uint256_reverse_endian(value);
    %{ index=0 %}
    tempvar range_check_ptr = range_check_ptr;
    tempvar bitwise_ptr = bitwise_ptr;
    tempvar count = 0;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    %{
        #print(f"{index=}/{ids.len}, {ids.count=}")
        index+=1
    %}
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) <= ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;

    if ([ap - 1] != FALSE) {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            [ap] = range_check_ptr, ap++;
            [ap] = bitwise_ptr, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    }

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let count = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return (res=count);
}
