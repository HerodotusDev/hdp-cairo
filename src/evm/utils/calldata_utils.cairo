// Calldata utilities for EVM
// Loading calldata words and push values from bytecode

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le

from src.evm.memory import Memory, memory_store

func _calldatacopy_loop{range_check_ptr}(
    memory: Memory, calldata: felt*, calldata_len: felt,
    dest: felt, src: felt, length: felt
) -> (new_memory: Memory) {
    if (length == 0) {
        return (new_memory=memory);
    }
    
    // Just copy one word at a time, simplified
    let (word) = load_calldata_word(calldata, calldata_len, src);
    let (m1) = memory_store(memory, dest, word);
    
    // Recurse for remaining (simplified: step by 32 even if length < 32)
    if (length == 32) {
        return (new_memory=m1);
    }
    
    // For remaining bytes, recurse
    let remaining = length - 32;
    let is_done = is_le(length, 32);
    if (is_done == 1) {
        return (new_memory=m1);
    }
    
    return _calldatacopy_loop(m1, calldata, calldata_len, dest + 32, src + 32, remaining);
}

// Get byte from 256-bit value (0 = MSB)
func _get_byte(i: felt, x_low: felt, x_high: felt) -> (byte_val: felt) {
    alloc_locals;
    local byte_val: felt;
    %{
        i = ids.i
        if i >= 32:
            ids.byte_val = 0
        else:
            if i < 16:
                byte_val = (ids.x_high >> (8 * (15 - i))) & 0xFF
            else:
                byte_val = (ids.x_low >> (8 * (31 - i))) & 0xFF
            ids.byte_val = byte_val
    %}
    return (byte_val=byte_val);
}

func read_push_value(bytecode: felt*, start: felt, n: felt, i: felt, acc: Uint256) -> (value: Uint256) {
    if (i == n) {
        return (value=acc);
    }
    
    let byte = [bytecode + start + i];
    
    // Shift acc left by 8 bits and add byte
    // Simple version for values that fit in low (< 16 bytes)
    let new_low = acc.low * 256 + byte;
    
    return read_push_value(bytecode, start, n, i + 1, Uint256(low=new_low, high=0));
}

func load_calldata_word(calldata: felt*, calldata_len: felt, offset: felt) -> (value: Uint256) {
    alloc_locals;
    
    // Read 32 bytes from offset, padding with zeros
    local b0: felt;
    local b1: felt;
    local b2: felt;
    local b3: felt;
    local b4: felt;
    local b5: felt;
    local b6: felt;
    local b7: felt;
    local b8: felt;
    local b9: felt;
    local b10: felt;
    local b11: felt;
    local b12: felt;
    local b13: felt;
    local b14: felt;
    local b15: felt;
    local b16: felt;
    local b17: felt;
    local b18: felt;
    local b19: felt;
    local b20: felt;
    local b21: felt;
    local b22: felt;
    local b23: felt;
    local b24: felt;
    local b25: felt;
    local b26: felt;
    local b27: felt;
    local b28: felt;
    local b29: felt;
    local b30: felt;
    local b31: felt;
    
    %{
        def get_byte(i):
            pos = ids.offset + i
            if pos < ids.calldata_len:
                return memory[ids.calldata + pos]
            return 0
        
        ids.b0 = get_byte(0)
        ids.b1 = get_byte(1)
        ids.b2 = get_byte(2)
        ids.b3 = get_byte(3)
        
        ids.b4 = get_byte(4)
        ids.b5 = get_byte(5)
        ids.b6 = get_byte(6)
        ids.b7 = get_byte(7)
        ids.b8 = get_byte(8)
        ids.b9 = get_byte(9)
        ids.b10 = get_byte(10)
        ids.b11 = get_byte(11)
        ids.b12 = get_byte(12)
        ids.b13 = get_byte(13)
        ids.b14 = get_byte(14)
        ids.b15 = get_byte(15)
        ids.b16 = get_byte(16)
        ids.b17 = get_byte(17)
        ids.b18 = get_byte(18)
        ids.b19 = get_byte(19)
        ids.b20 = get_byte(20)
        ids.b21 = get_byte(21)
        ids.b22 = get_byte(22)
        ids.b23 = get_byte(23)
        ids.b24 = get_byte(24)
        ids.b25 = get_byte(25)
        ids.b26 = get_byte(26)
        ids.b27 = get_byte(27)
        ids.b28 = get_byte(28)
        ids.b29 = get_byte(29)
        ids.b30 = get_byte(30)
        ids.b31 = get_byte(31)
    %}
    
    // Build high (first 16 bytes)
    let high = b0 * 0x1000000000000000000000000000000 +
               b1 * 0x10000000000000000000000000000 +
               b2 * 0x100000000000000000000000000 +
               b3 * 0x1000000000000000000000000 +
               b4 * 0x10000000000000000000000 +
               b5 * 0x100000000000000000000 +
               b6 * 0x1000000000000000000 +
               b7 * 0x10000000000000000 +
               b8 * 0x100000000000000 +
               b9 * 0x1000000000000 +
               b10 * 0x10000000000 +
               b11 * 0x100000000 +
               b12 * 0x1000000 +
               b13 * 0x10000 +
               b14 * 0x100 +
               b15;
    
    // Build low (last 16 bytes)
    let low = b16 * 0x1000000000000000000000000000000 +
              b17 * 0x10000000000000000000000000000 +
              b18 * 0x100000000000000000000000000 +
              b19 * 0x1000000000000000000000000 +
              b20 * 0x10000000000000000000000 +
              b21 * 0x100000000000000000000 +
              b22 * 0x1000000000000000000 +
              b23 * 0x10000000000000000 +
              b24 * 0x100000000000000 +
              b25 * 0x1000000000000 +
              b26 * 0x10000000000 +
              b27 * 0x100000000 +
              b28 * 0x1000000 +
              b29 * 0x10000 +
              b30 * 0x100 +
              b31;
    
    return (value=Uint256(low=low, high=high));
}

