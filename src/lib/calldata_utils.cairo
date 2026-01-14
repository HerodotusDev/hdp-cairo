// Calldata utilities for EVM
// Loading calldata words and push values from bytecode - Pure Cairo implementation

from starkware.cairo.common.uint256 import Uint256, uint256_mul, uint256_add
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.alloc import alloc
from src.evm.memory import Memory, memory_store, memory_store_byte

// Helper for Power of 256
func _pow256{range_check_ptr}(n: felt) -> (res: felt) {
    if (n == 0) {
        return (1,);
    }
    let (p) = _pow256(n - 1);
    return (p * 256,);
}

// Helper to get a single byte from calldata (with out of bounds handling)
func _get_calldata_byte{range_check_ptr}(calldata: felt*, calldata_len: felt, offset: felt) -> (byte: felt) {
    let too_big = is_le(calldata_len, offset);
    if (too_big == 1) {
        return (byte=0);
    }
    return (byte=calldata[offset]);
}

func _calldatacopy_loop{range_check_ptr}(
    memory: Memory, calldata: felt*, calldata_len: felt,
    dest: felt, src: felt, length: felt
) -> (new_memory: Memory) {
    alloc_locals;
    if (length == 0) {
        return (new_memory=memory);
    }
    
    // Determine how many bytes we can copy in this step (max 32)
    // To be perfectly safe and simple, we copy byte by byte for now.
    // Efficient word-level copy would require read-modify-write on memory.
    
    let (byte) = _get_calldata_byte(calldata, calldata_len, src);
    
    // Store 1 byte at dest
    let (m1) = memory_store_byte(memory, dest, byte);
    
    return _calldatacopy_loop(m1, calldata, calldata_len, dest + 1, src + 1, length - 1);
}

// Get byte from 256-bit value (0 = MSB)
func _get_byte{range_check_ptr}(i: felt, x_low: felt, x_high: felt) -> (byte_val: felt) {
    let too_big = is_le(32, i);
    if (too_big == 1) {
        return (byte_val=0);
    }
    
    // Determine high or low
    let in_high = is_le(i + 1, 16); // i < 16 -> i+1 <= 16
    
    if (in_high == 1) {
         // High part. Byte index from MSB (0..15).
         // Shift right by (15-i)*8 bits.
         // Div by 256^(15-i).
         // Mod 256.
         let p = 15 - i;
         let (pow) = _pow256(p);
         let (q, _) = unsigned_div_rem(x_high, pow);
         let (_, r) = unsigned_div_rem(q, 256);
         return (byte_val=r);
    } else {
         // Low part. Byte index 16..31.
         // local index k = i - 16. (0..15).
         // Shift right by (15-k)*8 = (31-i)*8.
         let p = 31 - i;
         let (pow) = _pow256(p);
         let (q, _) = unsigned_div_rem(x_low, pow);
         let (_, r) = unsigned_div_rem(q, 256);
         return (byte_val=r);
    }
}

func read_push_value{range_check_ptr}(bytecode: felt*, start: felt, n: felt, i: felt, acc: Uint256) -> (value: Uint256) {
    if (i == n) {
        return (value=acc);
    }
    let byte = bytecode[start + i];
    
    // acc = acc * 256 + byte
    let (acc_shifted, _) = uint256_mul(acc, Uint256(256, 0));
    let (acc_new, _) = uint256_add(acc_shifted, Uint256(byte, 0));
    
    return read_push_value(bytecode, start, n, i + 1, acc_new);
}

func load_calldata_word{range_check_ptr}(calldata: felt*, calldata_len: felt, offset: felt) -> (value: Uint256) {
    return _load_calldata_word_inner(calldata, calldata_len, offset, 0, Uint256(0, 0));
}

func _load_calldata_word_inner{range_check_ptr}(calldata: felt*, calldata_len: felt, offset: felt, i: felt, acc: Uint256) -> (value: Uint256) {
    alloc_locals;
    if (i == 32) {
        return (value=acc);
    }
    
    // Get byte
    let pos = offset + i;
    local byte: felt;
    let is_valid = is_le(pos + 1, calldata_len); // pos < len
    if (is_valid == 1) {
        assert byte = calldata[pos];
    } else {
        assert byte = 0;
    }
    
    let (acc_shifted, _) = uint256_mul(acc, Uint256(256, 0));
    let (acc_new, _) = uint256_add(acc_shifted, Uint256(byte, 0));
    
    return _load_calldata_word_inner(calldata, calldata_len, offset, i + 1, acc_new);
}
