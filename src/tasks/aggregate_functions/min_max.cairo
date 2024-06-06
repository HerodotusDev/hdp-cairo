from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    SHIFT,
    word_reverse_endian,
    uint256_reverse_endian,
)

// Retrieves the lowest Uin256 value from a Uint256 array.
// Params:
//   uint256_array: the array of Uint256 to search the minimum value.
//   len: the length of the array.
// returns:
//   res: the minimum value of the array.
// Completeness assumptions :
// - The array has valid Uint256 values in big endian representation.
// If len == 0, the function returns 0.
func uint256_min_be{range_check_ptr}(uint256_array: Uint256*, len: felt) -> Uint256 {
    if (len == 0) {
        let res = Uint256(low=0, high=0);
        return res;
    }
    alloc_locals;
    local min_index: felt;
    local array: felt* = cast(uint256_array, felt*);
    %{
        array = []
        index=0
        for i in range(ids.len):
            array.append(memory[ids.array+index+i] + memory[ids.array+index+i+1] * 2**128)
            index+=1
        min_index, min_value = min(enumerate(array), key=lambda x: x[1])
        ids.min_index = min_index
    %}
    // Assert index is in [0, len[
    assert [range_check_ptr] = min_index;
    assert [range_check_ptr + 1] = len - 1 - min_index;

    // Get supposed min value from array.
    local res: Uint256 = uint256_array[min_index];

    %{ index=0 %}
    tempvar range_check_ptr = range_check_ptr + 2;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let range_check_ptr = [ap - 2];
    let arr: felt* = cast([ap - 1], felt*);

    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    // %{ print(f"res({ids.res.low}, {ids.res.high}) should be <= val({ids.val_low}, {ids.val_high})") %}

    // Inlined starkware.cairo.common.uint256.uint256_lt in assert mode.
    if (val_high == res.high) {
        // If high parts are the same, assert res.low <= val.low
        assert [range_check_ptr] = val_low - res.low;
    } else {
        // If high parts are different, assert res.high <= val.high
        assert [range_check_ptr] = val_high - res.high;
    }
    [ap] = range_check_ptr + 1, ap++;
    [ap] = arr + Uint256.SIZE, ap++;
    %{ index+=1 %}
    jmp loop;

    end:
    let range_check_ptr = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return res;
}

// Retrieves the largest Uin256 value from a Uint256 array.
// Params:
//   uint256_array: the array of Uint256 to search the maximum value.
//   len: the length of the array.
// returns:
//   res: the maximum value of the array.
// Completeness assumptions :
// - The array has valid Uint256 values in big endian representation.
// If len == 0, the function returns 0.
func uint256_max_be{range_check_ptr}(uint256_array: Uint256*, len: felt) -> Uint256 {
    if (len == 0) {
        let res = Uint256(low=0, high=0);
        return res;
    }
    alloc_locals;
    local max_index: felt;
    local array: felt* = cast(uint256_array, felt*);
    %{
        array = []
        index=0
        for i in range(ids.len):
            array.append(memory[ids.array+index+i] + memory[ids.array+index+i+1] * 2**128)
            index+=1
        max_index, max_value = max(enumerate(array), key=lambda x: x[1])
        ids.max_index = max_index
    %}
    // Assert index is in [0, len[
    assert [range_check_ptr] = max_index;
    assert [range_check_ptr + 1] = len - 1 - max_index;

    // Get supposed max value from array.
    local res: Uint256 = uint256_array[max_index];

    %{ index=0 %}
    tempvar range_check_ptr = range_check_ptr + 2;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let range_check_ptr = [ap - 2];
    let arr: felt* = cast([ap - 1], felt*);
    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    // %{ print(f"res({ids.res.low}, {ids.res.high}) should be >= val({ids.val_low}, {ids.val_high})") %}

    // Inlined starkware.cairo.common.uint256.uint256_lt in assert mode.
    if (val_high == res.high) {
        // If high parts are the same, assert val_low <= res_low
        assert [range_check_ptr] = res.low - val_low;
    } else {
        // If high parts are different, assert val_high <= res_high
        assert [range_check_ptr] = res.high - val_high;
    }
    [ap] = range_check_ptr + 1, ap++;
    [ap] = arr + Uint256.SIZE, ap++;
    %{ index+=1 %}
    jmp loop;

    end:
    // Offset is increased by 1 due to the ap++ in the exit instruction.
    let range_check_ptr = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return res;
}

// Retrieves the lowest Uin256 value from a Uint256 array.
// Params:
//   uint256_array: the array of Uint256 to search the minimum value.
//   len: the length of the array.
// returns:
//   res: the minimum value of the array in big endian representation.
// Completeness assumptions :
// - The array has valid Uint256 values in little endian bytes representation.
// If len == 0, the function returns 0.
func uint256_min_le{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    uint256_array: Uint256*, len: felt
) -> Uint256 {
    if (len == 0) {
        let res = Uint256(low=0, high=0);
        return res;
    }
    alloc_locals;
    local min_index: felt;
    local array: felt* = cast(uint256_array, felt*);
    %{
        from tools.py.utils import uint256_reverse_endian
        array = []
        index=0
        for i in range(ids.len):
            array.append(memory[ids.array+index+i] + memory[ids.array+index+i+1] * 2**128)
            index+=1
        array = [uint256_reverse_endian(x) for x in array]
        min_index, min_value = min(enumerate(array), key=lambda x: x[1])
        ids.min_index = min_index
    %}
    // Assert index is in [0, len[
    assert [range_check_ptr] = min_index;
    assert [range_check_ptr + 1] = len - 1 - min_index;

    // Get supposed min value from array.
    local res_le: Uint256 = uint256_array[min_index];
    let (local res: Uint256) = uint256_reverse_endian(res_le);

    %{ index=0 %}
    tempvar bitwise_ptr = bitwise_ptr;
    tempvar range_check_ptr = range_check_ptr + 2;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let bitwise_ptr = cast([ap - 3], BitwiseBuiltin*);
    let range_check_ptr = [ap - 2];
    let arr: felt* = cast([ap - 1], felt*);

    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    // %{ print(f"res({ids.res.low}, {ids.res.high}) should be <= val({ids.val_low}, {ids.val_high})") %}

    // Inlined starkware.cairo.common.uint256.uint256_lt in assert mode.
    if (val_low == res_le.low) {
        // If high part (val_low in le case) are the same, assert res.low <= val.low
        // First, reverse low_part (<=> val_high in le case)
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
        assert [range_check_ptr] = val_low - res.low;
    } else {
        // If high parts are different, assert res.high <= val.high
        // First, reverse high_part (<=> val_low in le case)

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

        assert [range_check_ptr] = val_high - res.high;
    }
    [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
    [ap] = range_check_ptr + 1, ap++;
    [ap] = arr + Uint256.SIZE, ap++;
    %{ index+=1 %}
    jmp loop;

    end:
    let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
    let range_check_ptr = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return res;
}

// Retrieves the lowest Uin256 value from a Uint256 array.
// Params:
//   uint256_array: the array of Uint256 to search the minimum value.
//   len: the length of the array.
// returns:
//   res: the minimum value of the array in big endian representation.
// Completeness assumptions :
// - The array has valid Uint256 values in little endian bytes representation.
// If len == 0, the function returns 0.
func uint256_max_le{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    uint256_array: Uint256*, len: felt
) -> Uint256 {
    if (len == 0) {
        let res = Uint256(low=0, high=0);
        return res;
    }
    alloc_locals;
    local max_index: felt;
    local array: felt* = cast(uint256_array, felt*);
    %{
        from tools.py.utils import uint256_reverse_endian
        array = []
        index=0
        for i in range(ids.len):
            array.append(memory[ids.array+index+i] + memory[ids.array+index+i+1] * 2**128)
            index+=1
        array = [uint256_reverse_endian(x) for x in array]
        max_index, max_value = max(enumerate(array), key=lambda x: x[1])
        ids.max_index = max_index
    %}
    // Assert index is in [0, len[
    assert [range_check_ptr] = max_index;
    assert [range_check_ptr + 1] = len - 1 - max_index;

    // Get supposed min value from array.
    local res_le: Uint256 = uint256_array[max_index];
    let (local res: Uint256) = uint256_reverse_endian(res_le);

    %{ index=0 %}
    tempvar bitwise_ptr = bitwise_ptr;
    tempvar range_check_ptr = range_check_ptr + 2;
    tempvar arr: felt* = cast(array, felt*);

    loop:
    let bitwise_ptr = cast([ap - 3], BitwiseBuiltin*);
    let range_check_ptr = [ap - 2];
    let arr: felt* = cast([ap - 1], felt*);

    %{ memory[ap] = 1 if index == ids.len else 0 %}
    jmp end if [ap] != 0, ap++;
    let val_low = [arr];
    let val_high = [arr + 1];
    // %{ print(f"res({ids.res.low}, {ids.res.high}) should be >= val({ids.val_low}, {ids.val_high})") %}

    // Inlined starkware.cairo.common.uint256.uint256_lt in assert mode.
    if (val_low == res_le.low) {
        // If high part (val_low in le case) are the same, assert val_low <= res_low
        // First, reverse low_part (<=> val_high in le case)
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
        assert [range_check_ptr] = res.low - val_low;
    } else {
        // If high parts are different, assert res.high <= val.high
        // First, reverse high_part (<=> val_low in le case)
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

        assert [range_check_ptr] = res.high - val_high;
    }
    [ap] = bitwise_ptr + 4 * BitwiseBuiltin.SIZE, ap++;
    [ap] = range_check_ptr + 1, ap++;
    [ap] = arr + Uint256.SIZE, ap++;
    %{ index+=1 %}
    jmp loop;

    end:
    let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
    let range_check_ptr = [ap - 3];
    let arr: felt* = cast([ap - 2], felt*);
    assert cast(arr, felt) - cast(array, felt) = len * Uint256.SIZE;
    return res;
}
