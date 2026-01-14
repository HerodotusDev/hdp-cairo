// Uint256 utilities for Cairo Zero EVM

from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_mul,
    uint256_unsigned_div_rem,
    uint256_eq,
    uint256_lt,
    uint256_le,
    uint256_not,
    uint256_and,
    uint256_or,
    uint256_xor,
    uint256_shl,
    uint256_shr,
    SHIFT,
)
from starkware.cairo.common.math import unsigned_div_rem, split_felt
from starkware.cairo.common.math_cmp import is_le, is_nn
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

const UINT256_MAX_LOW = 2 ** 128 - 1;
const UINT256_MAX_HIGH = 2 ** 128 - 1;
const UINT128_BOUND = 2 ** 128;

// Check if uint256 is zero
func uint256_is_zero(x: Uint256) -> (res: felt) {
    if (x.low == 0) {
        if (x.high == 0) {
            return (res=1);
        }
    }
    return (res=0);
}

// Overflowing add
func uint256_overflowing_add{range_check_ptr}(a: Uint256, b: Uint256) -> (
    res: Uint256, overflow: felt
) {
    let (sum, carry) = uint256_add(a, b);
    return (res=sum, overflow=carry);
}

// Overflowing sub
func uint256_overflowing_sub{range_check_ptr}(a: Uint256, b: Uint256) -> (
    res: Uint256, underflow: felt
) {
    let (is_lt) = uint256_lt(a, b);
    if (is_lt == 1) {
        let (not_b) = uint256_not(b);
        let (not_b_plus_1, _) = uint256_add(not_b, Uint256(low=1, high=0));
        let (result, _) = uint256_add(not_b_plus_1, a);
        return (res=result, underflow=1);
    } else {
        let (result) = uint256_sub(a, b);
        return (res=result, underflow=0);
    }
}

// Overflowing mul
func uint256_overflowing_mul{range_check_ptr}(a: Uint256, b: Uint256) -> (
    res: Uint256, overflow: felt
) {
    let (low, high) = uint256_mul(a, b);
    let (high_is_zero) = uint256_is_zero(high);
    return (res=low, overflow=1 - high_is_zero);
}

// Safe division (0 if divisor is 0)
func uint256_safe_div{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256) {
    let (b_is_zero) = uint256_is_zero(b);
    if (b_is_zero == 1) {
        return (res=Uint256(low=0, high=0));
    }
    let (quotient, _) = uint256_unsigned_div_rem(a, b);
    return (res=quotient);
}

// Safe modulo (0 if divisor is 0)
func uint256_safe_mod{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256) {
    let (b_is_zero) = uint256_is_zero(b);
    if (b_is_zero == 1) {
        return (res=Uint256(low=0, high=0));
    }
    let (_, remainder) = uint256_unsigned_div_rem(a, b);
    return (res=remainder);
}

// Signed less than
func uint256_slt{range_check_ptr}(a: Uint256, b: Uint256) -> (res: felt) {
    alloc_locals;
    let a_negative = is_le(UINT128_BOUND / 2, a.high);
    let b_negative = is_le(UINT128_BOUND / 2, b.high);
    local saved_a_neg = a_negative;
    local saved_b_neg = b_negative;
    
    if (saved_a_neg == 1) {
        if (saved_b_neg == 0) {
            return (res=1);
        }
        tempvar range_check_ptr = range_check_ptr;
    } else {
        if (saved_b_neg == 1) {
            return (res=0);
        }
        tempvar range_check_ptr = range_check_ptr;
    }
    
    let (is_lt) = uint256_lt(a, b);
    return (res=is_lt);
}

// Signed greater than
func uint256_sgt{range_check_ptr}(a: Uint256, b: Uint256) -> (res: felt) {
    let (is_slt) = uint256_slt(b, a);
    return (res=is_slt);
}

// Get byte at position
func uint256_byte{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(i: Uint256, x: Uint256) -> (res: Uint256) {
    if (i.high != 0) {
        return (res=Uint256(low=0, high=0));
    }
    let ge_32 = is_le(32, i.low);
    if (ge_32 == 1) {
        return (res=Uint256(low=0, high=0));
    }
    
    let shift_bytes = 31 - i.low;
    let shift_bits = shift_bytes * 8;
    
    let (shifted) = uint256_shr(Uint256(low=shift_bits, high=0), x);
    let (result_low, _) = unsigned_div_rem(shifted.low, 256);
    let byte_val = shifted.low - result_low * 256;
    return (res=Uint256(low=byte_val, high=0));
}

// Arithmetic shift right
func uint256_sar{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(shift: Uint256, value: Uint256) -> (res: Uint256) {
    alloc_locals;
    local is_negative = is_le(UINT128_BOUND / 2, value.high);
    
    if (shift.high != 0) {
        if (is_negative == 1) {
            return (res=Uint256(low=UINT256_MAX_LOW, high=UINT256_MAX_HIGH));
        } else {
            return (res=Uint256(low=0, high=0));
        }
    }
    local ge_256 = is_le(256, shift.low);
    if (ge_256 == 1) {
        if (is_negative == 1) {
            return (res=Uint256(low=UINT256_MAX_LOW, high=UINT256_MAX_HIGH));
        } else {
            return (res=Uint256(low=0, high=0));
        }
    }
    
    let (local shifted) = uint256_shr(shift, value);
    
    if (is_negative == 1) {
        // Fill with 1s
        let fill_bits = 256 - shift.low;
        let (one_shifted) = uint256_shl(Uint256(low=fill_bits, high=0), Uint256(low=1, high=0));
        let (one_shifted_minus_1) = uint256_sub(one_shifted, Uint256(low=1, high=0));
        let (mask) = uint256_not(one_shifted_minus_1);
        let (result) = uint256_or(shifted, mask);
        return (res=result);
    } else {
        return (res=shifted);
    }
}
