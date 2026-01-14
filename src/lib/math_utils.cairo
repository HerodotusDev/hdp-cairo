// Math utilities for EVM operations
// 256-bit arithmetic operations using pure Cairo (replacing Python hints)

from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_mul, uint256_unsigned_div_rem, 
    uint256_lt
)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem

// Constants
const SHIFT_128 = 340282366920938463463374607431768211456; // 2**128

// Helper: 2^n in felt (requires n < 128)
func _pow2_felt(n: felt) -> (res: felt) {
    if (n == 0) {
        return (1,);
    }
    let (p) = _pow2_felt(n - 1);
    return (p * 2,);
}

// Helper: 2^n as Uint256 (n < 256)
func _pow2_uint256{range_check_ptr}(n: felt) -> (res: Uint256) {
    alloc_locals;
    // If n >= 128, low is 0, high is 2^(n-128)
    let is_high = is_le(128, n);
    local range_check_ptr = range_check_ptr; // Stable reference
    if (is_high == 1) {
        let (h_val) = _pow2_felt(n - 128);
        return (res=Uint256(0, h_val));
    } else {
        let (l_val) = _pow2_felt(n);
        return (res=Uint256(l_val, 0));
    }
}

// Helper: Negate Uint256 (2^256 - x) - No range check needed
func _uint256_neg(x: Uint256) -> (res: Uint256) {
    if (x.low == 0) {
        if (x.high == 0) {
            return (res=Uint256(0, 0));
        }
        return (res=Uint256(0, SHIFT_128 - x.high));
    }
    return (res=Uint256(SHIFT_128 - x.low, SHIFT_128 - 1 - x.high));
}

// Compute wrapping subtraction: (a - b) mod 2^256
func _compute_sub{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    let (neg_b) = _uint256_neg(Uint256(b_low, b_high));
    let (res, _) = uint256_add(Uint256(a_low, a_high), neg_b);
    return (result=res);
}

// Compute wrapping addition: (a + b) mod 2^256
func _compute_add{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    let (res, _) = uint256_add(Uint256(a_low, a_high), Uint256(b_low, b_high));
    return (result=res);
}

// Compute wrapping multiplication: (a * b) mod 2^256
func _compute_mul{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    let (low, _) = uint256_mul(Uint256(a_low, a_high), Uint256(b_low, b_high));
    return (result=low);
}

// Compute unsigned division: a / b (0 if b == 0)
func _compute_div{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    if (b_low == 0) {
        if (b_high == 0) {
            return (result=Uint256(0, 0));
        }
    }
    let (q, _) = uint256_unsigned_div_rem(Uint256(a_low, a_high), Uint256(b_low, b_high));
    return (result=q);
}

// Compute unsigned modulo: a % b
func _compute_mod{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    if (b_low == 0) {
        if (b_high == 0) {
            return (result=Uint256(0, 0));
        }
    }
    let (_, r) = uint256_unsigned_div_rem(Uint256(a_low, a_high), Uint256(b_low, b_high));
    return (result=r);
}

// Compute signed division: a / b (EVM semantics)
func _compute_sdiv{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    // Check divide by zero
    if (b_low == 0) {
        if (b_high == 0) {
            return (result=Uint256(0, 0));
        }
    }

    let is_neg_a = is_le(170141183460469231731687303715884105728, a_high); // 2^127
    let is_neg_b = is_le(170141183460469231731687303715884105728, b_high);

    local abs_a: Uint256;
    if (is_neg_a == 1) {
        let (val) = _uint256_neg(Uint256(a_low, a_high));
        assert abs_a = val;
    } else {
        assert abs_a = Uint256(a_low, a_high);
    }

    local abs_b: Uint256;
    if (is_neg_b == 1) {
        let (val) = _uint256_neg(Uint256(b_low, b_high));
        assert abs_b = val;
    } else {
        assert abs_b = Uint256(b_low, b_high);
    }

    let (q, _) = uint256_unsigned_div_rem(abs_a, abs_b);

    if (is_neg_a != is_neg_b) {
        let (neg_q) = _uint256_neg(q);
        return (result=neg_q);
    } else {
        return (result=q);
    }
}

// Compute signed modulo: a % b (EVM semantics)
func _compute_smod{range_check_ptr}(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    if (b_low == 0) {
        if (b_high == 0) {
            return (result=Uint256(0, 0));
        }
    }

    let is_neg_a = is_le(170141183460469231731687303715884105728, a_high);
    let is_neg_b = is_le(170141183460469231731687303715884105728, b_high);

    local abs_a: Uint256;
    if (is_neg_a == 1) {
        let (val) = _uint256_neg(Uint256(a_low, a_high));
        assert abs_a = val;
    } else {
        assert abs_a = Uint256(a_low, a_high);
    }

    local abs_b: Uint256;
    if (is_neg_b == 1) {
        let (val) = _uint256_neg(Uint256(b_low, b_high));
        assert abs_b = val;
    } else {
        assert abs_b = Uint256(b_low, b_high);
    }

    let (_, r) = uint256_unsigned_div_rem(abs_a, abs_b);

    if (is_neg_a == 1) {
        let (neg_r) = _uint256_neg(r);
        return (result=neg_r);
    } else {
        return (result=r);
    }
}

// Helper recurse exp
func _exp_recurse{range_check_ptr}(base: Uint256, exp: Uint256, acc: Uint256) -> (result: Uint256) {
    alloc_locals;
    if (exp.low == 0) {
        if (exp.high == 0) {
            return (result=acc);
        }
    }
    
    let (q, r_bit) = uint256_unsigned_div_rem(exp, Uint256(2, 0));
    
    local term: Uint256;
    if (r_bit.low == 1) {
        assert term = base;
    } else {
        assert term = Uint256(1, 0);
    }
    
    let (new_acc, _) = uint256_mul(acc, term);
    let (new_base, _) = uint256_mul(base, base);
    
    return _exp_recurse(new_base, q, new_acc);
}

// Compute exponentiation mod 2^256
func _compute_exp{range_check_ptr}(base_low: felt, base_high: felt, exp_low: felt, exp_high: felt) -> (result: Uint256) {
    let base = Uint256(base_low, base_high);
    let exp = Uint256(exp_low, exp_high);
    return _exp_recurse(base, exp, Uint256(1, 0));
}

// Shift Left
func _shl256{range_check_ptr}(val: Uint256, shift: felt) -> (result: Uint256) {
    alloc_locals;
    let too_big = is_le(256, shift);
    local range_check_ptr = range_check_ptr; // Stable reference
    if (too_big == 1) {
        return (result=Uint256(0, 0));
    }
    
    let (pow) = _pow2_uint256(shift);
    let (res, _) = uint256_mul(val, pow);
    return (result=res);
}

// Shift Right
func _shr256{range_check_ptr}(val: Uint256, shift: felt) -> (result: Uint256) {
    alloc_locals;
    let too_big = is_le(256, shift);
    local range_check_ptr = range_check_ptr; // Stable reference
    if (too_big == 1) {
        return (result=Uint256(0, 0));
    }
    
    let (pow) = _pow2_uint256(shift);
    let (q, _) = uint256_unsigned_div_rem(val, pow);
    return (result=q);
}

func _pow2(n: felt) -> felt {
    let (res) = _pow2_felt(n);
    return res;
}

func _uint256_lt{range_check_ptr}(a: Uint256, b: Uint256) -> felt {
    let (res) = uint256_lt(a, b);
    return res;
}

func _compute_addmod(a_low: felt, a_high: felt, b_low: felt, b_high: felt, n_low: felt, n_high: felt) -> (result: Uint256) {
    // Legacy implementation - hints remain
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        n = ids.n_low + ids.n_high * 2**128
        if n == 0:
            result = 0
        else:
            result = (a + b) % n
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

func _compute_mulmod(a_low: felt, a_high: felt, b_low: felt, b_high: felt, n_low: felt, n_high: felt) -> (result: Uint256) {
    // Legacy implementation - hints remain
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        n = ids.n_low + ids.n_high * 2**128
        if n == 0:
            result = 0
        else:
            result = (a * b) % n
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}
