// Bitwise operations for Uint256
// Uses Cairo's bitwise builtin

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Bitwise AND for Uint256
func uint256_and{bitwise_ptr: BitwiseBuiltin*}(a: Uint256, b: Uint256) -> (result: Uint256) {
    alloc_locals;
    let (local low) = bitwise_and_felt(a.low, b.low);
    let (local high) = bitwise_and_felt(a.high, b.high);
    return (result=Uint256(low=low, high=high));
}

func bitwise_and_felt{bitwise_ptr: BitwiseBuiltin*}(x: felt, y: felt) -> (result: felt) {
    assert bitwise_ptr.x = x;
    assert bitwise_ptr.y = y;
    let result = bitwise_ptr.x_and_y;
    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return (result=result);
}

// Bitwise OR for Uint256
func uint256_or{bitwise_ptr: BitwiseBuiltin*}(a: Uint256, b: Uint256) -> (result: Uint256) {
    alloc_locals;
    let (local low) = bitwise_or_felt(a.low, b.low);
    let (local high) = bitwise_or_felt(a.high, b.high);
    return (result=Uint256(low=low, high=high));
}

func bitwise_or_felt{bitwise_ptr: BitwiseBuiltin*}(x: felt, y: felt) -> (result: felt) {
    assert bitwise_ptr.x = x;
    assert bitwise_ptr.y = y;
    let result = bitwise_ptr.x_or_y;
    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return (result=result);
}

// Bitwise XOR for Uint256
func uint256_xor{bitwise_ptr: BitwiseBuiltin*}(a: Uint256, b: Uint256) -> (result: Uint256) {
    alloc_locals;
    let (local low) = bitwise_xor_felt(a.low, b.low);
    let (local high) = bitwise_xor_felt(a.high, b.high);
    return (result=Uint256(low=low, high=high));
}

func bitwise_xor_felt{bitwise_ptr: BitwiseBuiltin*}(x: felt, y: felt) -> (result: felt) {
    assert bitwise_ptr.x = x;
    assert bitwise_ptr.y = y;
    let result = bitwise_ptr.x_xor_y;
    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;
    return (result=result);
}

