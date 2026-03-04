// Math utilities for EVM operations
// 256-bit arithmetic operations using hints

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le

// Compute wrapping subtraction: (a - b) mod 2^256
func _compute_sub(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        result = (a - b) % (2**256)
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute wrapping addition: (a + b) mod 2^256
func _compute_add(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        result = (a + b) % (2**256)
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute wrapping multiplication: (a * b) mod 2^256
func _compute_mul(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        result = (a * b) % (2**256)
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute unsigned division: a / b (0 if b == 0)
func _compute_div(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        if b == 0:
            result = 0
        else:
            result = a // b
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute signed division: a / b (EVM semantics)
func _compute_sdiv(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        def to_signed(val):
            if val >= 2**255:
                return val - 2**256
            return val
        
        def from_signed(val):
            if val < 0:
                return val + 2**256
            return val
        
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        if b == 0:
            result = 0
        else:
            a_signed = to_signed(a)
            b_signed = to_signed(b)
            # Python's // truncates toward negative infinity, EVM truncates toward zero
            if (a_signed < 0) != (b_signed < 0):
                result = from_signed(-(abs(a_signed) // abs(b_signed)))
            else:
                result = abs(a_signed) // abs(b_signed)
        ids.result_low = result % (2**128)
        ids.result_high = (result // (2**128)) % (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute unsigned modulo: a % b
func _compute_mod(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        if b == 0:
            result = 0
        else:
            result = a % b
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute signed modulo: a % b (EVM semantics)
func _compute_smod(a_low: felt, a_high: felt, b_low: felt, b_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        def to_signed(val):
            if val >= 2**255:
                return val - 2**256
            return val
        
        def from_signed(val):
            if val < 0:
                return val + 2**256
            return val
        
        a = ids.a_low + ids.a_high * 2**128
        b = ids.b_low + ids.b_high * 2**128
        if b == 0:
            result = 0
        else:
            a_signed = to_signed(a)
            b_signed = to_signed(b)
            # EVM SMOD: sign of result matches sign of a
            mod_result = abs(a_signed) % abs(b_signed)
            if a_signed < 0:
                result = from_signed(-mod_result)
            else:
                result = mod_result
        ids.result_low = result % (2**128)
        ids.result_high = (result // (2**128)) % (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Compute addmod: (a + b) % n
func _compute_addmod(a_low: felt, a_high: felt, b_low: felt, b_high: felt, n_low: felt, n_high: felt) -> (result: Uint256) {
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

// Compute mulmod: (a * b) % n
func _compute_mulmod(a_low: felt, a_high: felt, b_low: felt, b_high: felt, n_low: felt, n_high: felt) -> (result: Uint256) {
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

// Compute exponentiation mod 2^256
func _compute_exp(base_low: felt, base_high: felt, exp_low: felt, exp_high: felt) -> (result: Uint256) {
    alloc_locals;
    local result_low: felt;
    local result_high: felt;
    %{
        base_val = ids.base_low + ids.base_high * 2**128
        exp_val = ids.exp_low + ids.exp_high * 2**128
        if exp_val == 0:
            result = 1
        else:
            result = pow(base_val, exp_val, 2**256)
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Shift right for Uint256
// Left shift by n bits (256-bit)
func _shl256{range_check_ptr}(val: Uint256, shift: felt) -> (result: Uint256) {
    alloc_locals;
    
    // Handle shift >= 256
    let is_huge = is_le(256, shift);
    if (is_huge == 1) {
        return (result=Uint256(low=0, high=0));
    }
    
    // Use hint for complex shift
    local result_low: felt;
    local result_high: felt;
    %{
        val = ids.val.low + ids.val.high * 2**128
        shift = ids.shift
        if shift >= 256:
            result = 0
        else:
            result = (val << shift) % (2**256)
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Right shift by n bits (256-bit)
func _shr256{range_check_ptr}(val: Uint256, shift: felt) -> (result: Uint256) {
    alloc_locals;
    
    // Handle shift >= 256
    let is_huge = is_le(256, shift);
    if (is_huge == 1) {
        return (result=Uint256(low=0, high=0));
    }
    
    // Use hint for complex shift
    local result_low: felt;
    local result_high: felt;
    %{
        val = ids.val.low + ids.val.high * 2**128
        shift = ids.shift
        if shift >= 256:
            result = 0
        else:
            result = val >> shift
        ids.result_low = result % (2**128)
        ids.result_high = result // (2**128)
    %}
    return (result=Uint256(low=result_low, high=result_high));
}

// Power of 2 helper - use hint for any value
func _pow2{range_check_ptr}(n: felt) -> felt {
    alloc_locals;
    // For n >= 252, result would exceed felt range
    local is_valid: felt = is_le(n, 251);
    if (is_valid == 0) {
        return 0;
    }
    local result: felt;
    %{ ids.result = 2 ** ids.n %}
    return result;
}

// Compare a < b for Uint256
func _uint256_lt{range_check_ptr}(a: Uint256, b: Uint256) -> felt {
    let high_lt = is_le(a.high + 1, b.high);
    if (high_lt == 1) {
        return 1;
    }
    if (a.high != b.high) {
        return 0;
    }
    // high is equal, compare low
    let low_lt = is_le(a.low + 1, b.low);
    return low_lt;
}

