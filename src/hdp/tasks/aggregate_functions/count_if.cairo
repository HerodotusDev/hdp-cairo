from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from starkware.cairo.common.uint256 import (
    Uint256,
    SHIFT,
    word_reverse_endian,
    uint256_reverse_endian,
)

from src.libs.utils import uint256_add, uint256_sub

const TRUE = 1;
const FALSE = 0;

// we start with index 1, as solidity handles undefined as 0
namespace COUNT_IF {
    const EQ = 1;  // ==
    const NEQ = 2;  // !=
    const GT = 3;  // >
    const GE = 4;  // >=
    const LT = 5;  // <
    const LE = 6;  // <=
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
    %{ from tools.py.utils import uint256_reverse_endian %}
    %{
        #print(f"{COUNTIFOP(ids.op)}")
        #print(f"value={ids.value.low + 2**128* ids.value.high}")
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

// Computes sum (arr[i] == value)
// Assumptions :
// Array is in little endian.
// Value is in big endian.
// Comparison is made in big endian.
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

// Computes sum (arr[i] != value)
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

    let (local value_plus_one: Uint256, _) = uint256_add(value, Uint256(1, 0));
    let (local val_plus_one_le: Uint256) = uint256_reverse_endian(value_plus_one);
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
        if (val_low == val_plus_one_le.low) {
            // If high parts match, only reverse low part.
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;

            tempvar val_low = word / 2 ** (8 + 16 + 32 + 64);
            // assert val_low >= value_plus_one.low
            assert [range_check_ptr] = val_low - value_plus_one.low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            // If high part don't match, assert array[i]_high >= value_high.
            // Reverse the endianness of high part.

            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high = word / 2 ** (8 + 16 + 32 + 64);
            // assert val_high >= value_high
            assert [range_check_ptr] = val_high - value_plus_one.high;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;

            tempvar val_low = word / 2 ** (8 + 16 + 32 + 64);
            // assert value_low >= val_low
            assert [range_check_ptr] = value.low - val_low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = value.high - val_high;

            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
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

    let (local val_min_one: Uint256) = uint256_sub(value, Uint256(low=1, high=0));
    let (local val_min_one_le: Uint256) = uint256_reverse_endian(val_min_one);
    let (local val_le: Uint256) = uint256_reverse_endian(value);

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
    %{ index+=1 %}
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) >= ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;
    if ([ap - 1] != FALSE) {
        // Assert array[i] >= value
        if (val_low == val_le.low) {
            // If high parts match, compare low parts.
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;

            tempvar val_low = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_low - value.low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_high - value.high;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] < value <=> array[i] <= value - 1
        if (val_low == val_min_one_le.low) {
            // If high part match, compare low part.
            // Reverse low part to compare it.
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;

            tempvar val_low = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_min_one.low - val_low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high = word / 2 ** (8 + 16 + 32 + 64);

            assert [range_check_ptr] = val_min_one.high - val_high;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
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

    let (local val_min_one: Uint256) = uint256_sub(value, Uint256(1, 0));
    let (local val_min_one_le: Uint256) = uint256_reverse_endian(val_min_one);
    let (local val_le: Uint256) = uint256_reverse_endian(Uint256(value.low, value.high));
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
    %{ index+=1 %}
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) < ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;

    if ([ap - 1] != FALSE) {
        // Assert array[i] < value <=> array[i] <= value - 1
        if (val_low == val_min_one_le.low) {
            // High part match. Compare low parts.
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;

            tempvar val_low = word / 2 ** (8 + 16 + 32 + 64);

            assert [range_check_ptr] = val_min_one.low - val_low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_min_one.high - val_high;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] >= value
        if (val_low == val_le.low) {
            // if high parts match, assert array[i]_low >= value_low.
            // Reverse the endianness of low part.
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_low_be = word / 2 ** (8 + 16 + 32 + 64);
            // Asserts val_low_be >= value.low.
            assert [range_check_ptr] = val_low_be - value.low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            // if high parts are different, assert array[i]_high >= value_high.
            // Reverse the endianness of high part.
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high_be = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_high_be - value.high;

            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
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

    let (local val_plus_one: Uint256, carry) = uint256_add(value, Uint256(1, 0));
    assert carry = 0;
    let (local val_le: Uint256) = uint256_reverse_endian(value);
    let (local val_plus_one_le: Uint256) = uint256_reverse_endian(val_plus_one);
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
    %{ memory[ap] = ids.TRUE if uint256_reverse_endian(memory[ids.arr] + 2**128 * memory[ids.arr+1]) <= ids.value.low + 2**128 * ids.value.high else ids.FALSE %}
    ap += 1;

    if ([ap - 1] != FALSE) {
        // Assert array[i] <= value
        if (val_low == val_le.low) {
            // If high part matches, assert array[i]_low <= value_low
            // Reverse the endianness of low part.
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_low_be = word / 2 ** (8 + 16 + 32 + 64);
            // Asserts val_low_be <= value.low.
            assert [range_check_ptr] = value.low - val_low_be;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high_be = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = value.high - val_high_be;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count + 1, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        }
    } else {
        // Assert array[i] > value <=> array[i] >= value + 1
        if (val_low == val_plus_one_le.low) {
            assert bitwise_ptr[0].x = val_high;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_high + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_low_be = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_low_be - val_plus_one.low;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
            [ap] = count, ap++;
            [ap] = arr + Uint256.SIZE, ap++;
            jmp loop;
        } else {
            assert bitwise_ptr[0].x = val_low;
            assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff00ff00ff00ff00ff;
            tempvar word = val_low + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
            assert bitwise_ptr[1].x = word;
            assert bitwise_ptr[1].y = 0x00ffff0000ffff0000ffff0000ffff00;
            tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
            assert bitwise_ptr[2].x = word;
            assert bitwise_ptr[2].y = 0x00ffffffff00000000ffffffff000000;
            tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;
            assert bitwise_ptr[3].x = word;
            assert bitwise_ptr[3].y = 0x00ffffffffffffffff00000000000000;
            tempvar word = word + (2 ** 128 - 1) * bitwise_ptr[3].x_and_y;
            tempvar val_high_be = word / 2 ** (8 + 16 + 32 + 64);
            assert [range_check_ptr] = val_high_be - val_plus_one.high;
            [ap] = range_check_ptr + 1, ap++;
            [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
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
