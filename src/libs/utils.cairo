from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.uint256 import (
    Uint256,
    SHIFT,
    word_reverse_endian,
    uint256_reverse_endian,
)
from starkware.cairo.common.registers import get_fp_and_pc

const DIV_32 = 2 ** 32;
const DIV_32_MINUS_1 = DIV_32 - 1;

// Fast version of common.uint256.uint256_add.
func uint256_add{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256, carry: felt) {
    alloc_locals;
    local carry_low: felt;
    local carry_high: felt;
    %{
        sum_low = ids.a.low + ids.b.low
        ids.carry_low = 1 if sum_low >= ids.SHIFT else 0
        sum_high = ids.a.high + ids.b.high + ids.carry_low
        ids.carry_high = 1 if sum_high >= ids.SHIFT else 0
    %}

    if (carry_low != 0) {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1 - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 1);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 0);
        }
    } else {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 1);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 0);
        }
    }
}

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
        from tools.py.utils import reverse_endian_256
        array = []
        index=0
        for i in range(ids.len):
            array.append(memory[ids.array+index+i] + memory[ids.array+index+i+1] * 2**128)
            index+=1
        array = [reverse_endian_256(x) for x in array]
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
    if (val_low == res.high) {
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
        from tools.py.utils import reverse_endian_256
        array = []
        index=0
        for i in range(ids.len):
            array.append(memory[ids.array+index+i] + memory[ids.array+index+i+1] * 2**128)
            index+=1
        array = [reverse_endian_256(x) for x in array]
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
    if (val_low == res.high) {
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

// Write the elements of the array as key in the dictionnary and assign the value 0 to each key.
// Used to check that an element in the dict is present by checking dict[key] == 1.
// Use with a default_dict with default_value = 0.
// If the element is present, the value will be 1.
// If the element is not present, the value will be 0.
func write_felt_array_to_dict_keys{dict_end: DictAccess*}(array: felt*, index: felt) {
    if (index == -1) {
        return ();
    } else {
        dict_write{dict_ptr=dict_end}(key=array[index], new_value=1);
        return write_felt_array_to_dict_keys(array, index - 1);
    }
}

// Returns the number of bits in x.
// Implicits arguments:
// - pow2_array: felt* - A pointer such that pow2_array[i] = 2^i for i in [0, 127].
// Params:
// - x: felt - Input value.
// Assumptions for the caller:
// - 1 <= x < 2^127
// Returns:
// - bit_length: felt - Number of bits in x.
func get_felt_bitlength{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{
        x = ids.x
        ids.bit_length = x.bit_length()
    %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits
    tempvar N = pow2_array[bit_length];
    tempvar n = pow2_array[bit_length - 1];
    assert [range_check_ptr] = bit_length;
    assert [range_check_ptr + 1] = 127 - bit_length;
    assert [range_check_ptr + 2] = N - x - 1;
    assert [range_check_ptr + 3] = x - n;
    tempvar range_check_ptr = range_check_ptr + 4;
    return bit_length;
}

// Computes x//y and x%y.
// Assumption: y must be a power of 2
// params:
//   x: the dividend.
//   y: the divisor.
// returns:
//   q: the quotient.
//   r: the remainder.
func bitwise_divmod{bitwise_ptr: BitwiseBuiltin*}(x: felt, y: felt) -> (q: felt, r: felt) {
    assert bitwise_ptr.x = x;
    assert bitwise_ptr.y = y - 1;
    let x_and_y = bitwise_ptr.x_and_y;

    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return (q=(x - x_and_y) / y, r=x_and_y);
}

// Computes x//(2**32) and x%(2**32) using range checks operations.
// Adapted version of starkware.common.math.unsigned_div_rem with a fixed divisor of 2**32.
// Assumption : value / 2**32 < RC_BOUND
// params:
//   x: the dividend.
// returns:
//   q: the quotient .
//   r: the remainder.
func felt_divmod_2pow32{range_check_ptr}(value: felt) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.DIV_32)
        assert 0 < ids.DIV_32 <= PRIME // range_check_builtin.bound, \
            f'div={hex(ids.DIV_32)} is out of the valid range.'
        ids.q, ids.r = divmod(ids.value, ids.DIV_32)
    %}
    assert [range_check_ptr + 2] = DIV_32_MINUS_1 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * DIV_32 + r;
    return (q, r);
}

// Computes x//8 and x%8 using range checks operations.
// Adapted version of starkware.common.math.unsigned_div_rem with a fixed divisor of 2**32.
// Assumption : value / 8 < RC_BOUND
// params:
//   x: the dividend.
// returns:
//   q: the quotient .
//   r: the remainder.
func felt_divmod_8{range_check_ptr}(value: felt) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{ ids.q, ids.r = divmod(ids.value, 8) %}
    assert [range_check_ptr + 2] = 7 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * 8 + r;
    return (q, r);
}

// Returns q and r such that:
//  0 <= q < rc_bound, 0 <= r < div and value = q * div + r.
//
// Assumption: 0 < div <= PRIME / rc_bound.
// Prover assumption: value / div < rc_bound.
// Modified version of unsigned_div_rem with inlined range checks.
func felt_divmod{range_check_ptr}(value, div) -> (q: felt, r: felt) {
    let r = [range_check_ptr];
    let q = [range_check_ptr + 1];
    %{
        from starkware.cairo.common.math_utils import assert_integer
        assert_integer(ids.div)
        assert 0 < ids.div <= PRIME // range_check_builtin.bound, \
            f'div={hex(ids.div)} is out of the valid range.'
        ids.q, ids.r = divmod(ids.value, ids.div)
    %}
    assert [range_check_ptr + 2] = div - 1 - r;
    let range_check_ptr = range_check_ptr + 3;

    assert value = q * div + r;
    return (q, r);
}

// A function to reverse the byte endianness of a 8 bytes (64 bits) integer.
// The result will not make sense if word >= 2^64.
// The implementation is directly inspired by the function word_reverse_endian
// from the common library starkware.cairo.common.uint256 with three steps instead of four.
// params:
//   word: the 64 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_64{bitwise_ptr: BitwiseBuiltin*}(word: felt) -> (res: felt) {
    // Step 1.
    assert bitwise_ptr[0].x = word;
    assert bitwise_ptr[0].y = 0x00ff00ff00ff00ff;
    tempvar word = word + (2 ** 16 - 1) * bitwise_ptr[0].x_and_y;
    // Step 2.
    assert bitwise_ptr[1].x = word;
    assert bitwise_ptr[1].y = 0x0000ffff0000ffff00;
    tempvar word = word + (2 ** 32 - 1) * bitwise_ptr[1].x_and_y;
    // Step 3.
    assert bitwise_ptr[2].x = word;
    assert bitwise_ptr[2].y = 0x00000000ffffffff000000;
    tempvar word = word + (2 ** 64 - 1) * bitwise_ptr[2].x_and_y;

    let bitwise_ptr = bitwise_ptr + 3 * BitwiseBuiltin.SIZE;
    return (res=word / 2 ** (8 + 16 + 32));
}

// A function to reverse the byte endianness of a 2 bytes (16 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^16.
// params:
//   word: the 16 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_16_RC{range_check_ptr}(word: felt) -> felt {
    %{
        word = ids.word
        assert word < 2**16
        word_bytes=word.to_bytes(2, byteorder='big')
        for i in range(2):
            memory[ap+i] = word_bytes[i]
    %}
    ap += 2;

    let b0 = [ap - 2];
    let b1 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = b0;
    assert [range_check_ptr + 3] = b1;

    assert word = b0 * 256 + b1;

    tempvar range_check_ptr = range_check_ptr + 4;
    return b0 + b1 * 256;
}

// A function to reverse the byte endianness of a 3 bytes (24 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^24.
// params:
//   word: the 24 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_24_RC{range_check_ptr}(word: felt) -> felt {
    %{
        word = ids.word
        assert word < 2**24
        word_bytes=word.to_bytes(3, byteorder='big')
        for i in range(3):
            memory[ap+i] = word_bytes[i]
    %}
    ap += 3;

    let b0 = [ap - 3];
    let b1 = [ap - 2];
    let b2 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = b0;
    assert [range_check_ptr + 4] = b1;
    assert [range_check_ptr + 5] = b2;

    assert word = b0 * 256 ** 2 + b1 * 256 + b2;

    tempvar range_check_ptr = range_check_ptr + 6;
    return b0 + b1 * 256 + b2 * 256 ** 2;
}

// A function to reverse the byte endianness of a 4 bytes (32 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^32.
// params:
//   word: the 32 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_32_RC{range_check_ptr}(word: felt) -> felt {
    %{
        word = ids.word
        assert word < 2**32
        word_bytes=word.to_bytes(4, byteorder='big')
        for i in range(4):
            memory[ap+i] = word_bytes[i]
    %}
    ap += 4;

    let b0 = [ap - 4];
    let b1 = [ap - 3];
    let b2 = [ap - 2];
    let b3 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = b0;
    assert [range_check_ptr + 5] = b1;
    assert [range_check_ptr + 6] = b2;
    assert [range_check_ptr + 7] = b3;

    assert word = b0 * 256 ** 3 + b1 * 256 ** 2 + b2 * 256 + b3;

    tempvar range_check_ptr = range_check_ptr + 8;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3;
}

// A function to reverse the byte endianness of a 5 bytes (40 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^40.
// params:
//   word: the 40 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_40_RC{range_check_ptr}(word: felt) -> felt {
    %{
        word = ids.word
        assert word < 2**40
        word_bytes=word.to_bytes(5, byteorder='big')
        for i in range(5):
            memory[ap+i] = word_bytes[i]
    %}
    ap += 5;

    let b0 = [ap - 5];
    let b1 = [ap - 4];
    let b2 = [ap - 3];
    let b3 = [ap - 2];
    let b4 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = 255 - b4;
    assert [range_check_ptr + 5] = b0;
    assert [range_check_ptr + 6] = b1;
    assert [range_check_ptr + 7] = b2;
    assert [range_check_ptr + 8] = b3;
    assert [range_check_ptr + 9] = b4;

    assert word = b0 * 256 ** 4 + b1 * 256 ** 3 + b2 * 256 ** 2 + b3 * 256 + b4;

    tempvar range_check_ptr = range_check_ptr + 10;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3 + b4 * 256 ** 4;
}

// A function to reverse the byte endianness of a 6 bytes (48 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^48.
// params:
//   word: the 48 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_48_RC{range_check_ptr}(word: felt) -> felt {
    %{
        word = ids.word
        assert word < 2**48
        word_bytes=word.to_bytes(6, byteorder='big')
        for i in range(6):
            memory[ap+i] = word_bytes[i]
    %}
    ap += 6;

    let b0 = [ap - 6];
    let b1 = [ap - 5];
    let b2 = [ap - 4];
    let b3 = [ap - 3];
    let b4 = [ap - 2];
    let b5 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = 255 - b4;
    assert [range_check_ptr + 5] = 255 - b5;
    assert [range_check_ptr + 6] = b0;
    assert [range_check_ptr + 7] = b1;
    assert [range_check_ptr + 8] = b2;
    assert [range_check_ptr + 9] = b3;
    assert [range_check_ptr + 10] = b4;
    assert [range_check_ptr + 11] = b5;

    assert word = b0 * 256 ** 5 + b1 * 256 ** 4 + b2 * 256 ** 3 + b3 * 256 ** 2 + b4 * 256 + b5;

    tempvar range_check_ptr = range_check_ptr + 12;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3 + b4 * 256 ** 4 + b5 * 256 ** 5;
}

// A function to reverse the byte endianness of a 7 bytes (56 bits) integer using range checks operations.
// Asuumes 0 <= word < 2^56.
// params:
//   word: the 56 bits integer to reverse.
// returns:
//   res: the byte-reversed integer.
func word_reverse_endian_56_RC{range_check_ptr}(word: felt) -> felt {
    %{
        word = ids.word
        assert word < 2**56
        word_bytes=word.to_bytes(7, byteorder='big')
        for i in range(7):
            memory[ap+i] = word_bytes[i]
    %}
    ap += 7;

    let b0 = [ap - 7];
    let b1 = [ap - 6];
    let b2 = [ap - 5];
    let b3 = [ap - 4];
    let b4 = [ap - 3];
    let b5 = [ap - 2];
    let b6 = [ap - 1];

    assert [range_check_ptr] = 255 - b0;
    assert [range_check_ptr + 1] = 255 - b1;
    assert [range_check_ptr + 2] = 255 - b2;
    assert [range_check_ptr + 3] = 255 - b3;
    assert [range_check_ptr + 4] = 255 - b4;
    assert [range_check_ptr + 5] = 255 - b5;
    assert [range_check_ptr + 6] = 255 - b6;
    assert [range_check_ptr + 7] = b0;
    assert [range_check_ptr + 8] = b1;
    assert [range_check_ptr + 9] = b2;
    assert [range_check_ptr + 10] = b3;
    assert [range_check_ptr + 11] = b4;
    assert [range_check_ptr + 12] = b5;
    assert [range_check_ptr + 13] = b6;

    assert word = b0 * 256 ** 6 + b1 * 256 ** 5 + b2 * 256 ** 4 + b3 * 256 ** 3 + b4 * 256 ** 2 +
        b5 * 256 + b6;

    tempvar range_check_ptr = range_check_ptr + 14;
    return b0 + b1 * 256 + b2 * 256 ** 2 + b3 * 256 ** 3 + b4 * 256 ** 4 + b5 * 256 ** 5 + b6 *
        256 ** 6;
}

func get_0xff_mask(n: felt) -> felt {
    let (_, pc) = get_fp_and_pc();

    pc_labelx:
    let data = pc + (n_0xff - pc_labelx);

    let res = [data + n];

    return res;

    n_0xff:
    dw 0;
    dw 0xff;
    dw 0xffff;
    dw 0xffffff;
    dw 0xffffffff;
    dw 0xffffffffff;
    dw 0xffffffffffff;
    dw 0xffffffffffffff;
    dw 0xffffffffffffffff;
}

// Utility to get a pointer on an array of 2^i from i = 0 to 127.
func pow2alloc127() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
}

// Utility to get a pointer on an array of 2^i from i = 0 to 128.
func pow2alloc128() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
    dw 0x100000000000000000000000000000000;
}
