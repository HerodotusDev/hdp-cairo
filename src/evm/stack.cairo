// Simplified Array-based Stack
// Always maintains: depth == top_idx
// Data is contiguous from position 0 to depth-1
// Top of stack is at position (depth - 1)

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le

struct Stack {
    data: felt*,
    depth: felt,
    top_idx: felt,  // Always equals depth
}

// Create empty stack
func stack_new() -> (stack: Stack) {
    let (data) = alloc();
    return (stack=Stack(data=data, depth=0, top_idx=0));
}

// Push a value - O(1)
func stack_push(stack: Stack, value: Uint256) -> (new_stack: Stack) {
    let idx = stack.depth * 2;
    assert [stack.data + idx] = value.low;
    assert [stack.data + idx + 1] = value.high;
    return (new_stack=Stack(data=stack.data, depth=stack.depth + 1, top_idx=stack.depth + 1));
}

// Pop a value - O(depth) due to copy
func stack_pop(stack: Stack) -> (new_stack: Stack, value: Uint256, err: felt) {
    alloc_locals;
    if (stack.depth == 0) {
        return (new_stack=stack, value=Uint256(low=0, high=0), err=1);
    }
    
    // Top is at depth - 1
    let top_idx = (stack.depth - 1) * 2;
    local low: felt = [stack.data + top_idx];
    local high: felt = [stack.data + top_idx + 1];
    
    // Copy remaining stack (positions 0 to depth-2) to new array
    let (new_data) = alloc();
    let new_depth = stack.depth - 1;
    _copy_stack(stack.data, new_data, new_depth, 0);
    
    return (new_stack=Stack(data=new_data, depth=new_depth, top_idx=new_depth), 
            value=Uint256(low=low, high=high), err=0);
}

// Copy n elements from src to dst
func _copy_stack(src: felt*, dst: felt*, n: felt, i: felt) {
    if (i == n) {
        return ();
    }
    let idx = i * 2;
    assert [dst + idx] = [src + idx];
    assert [dst + idx + 1] = [src + idx + 1];
    return _copy_stack(src, dst, n, i + 1);
}

// Peek at top - O(1)
func stack_peek(stack: Stack) -> (value: Uint256, err: felt) {
    if (stack.depth == 0) {
        return (value=Uint256(low=0, high=0), err=1);
    }
    
    let idx = (stack.depth - 1) * 2;
    let low = [stack.data + idx];
    let high = [stack.data + idx + 1];
    return (value=Uint256(low=low, high=high), err=0);
}

// Peek at nth from top (1 = top, 2 = second from top, etc.) - O(1)
func stack_peek_n{range_check_ptr}(stack: Stack, n: felt) -> (value: Uint256, err: felt) {
    let has_enough = is_le(n, stack.depth);
    if (has_enough == 0) {
        return (value=Uint256(low=0, high=0), err=1);
    }
    
    // nth from top is at position (depth - n)
    let idx = (stack.depth - n) * 2;
    let low = [stack.data + idx];
    let high = [stack.data + idx + 1];
    return (value=Uint256(low=low, high=high), err=0);
}

// Swap top with nth from top - O(depth) due to copy
func stack_swap{range_check_ptr}(stack: Stack, n: felt) -> (new_stack: Stack, err: felt) {
    alloc_locals;
    let has_enough = is_le(n + 1, stack.depth);
    if (has_enough == 0) {
        return (new_stack=stack, err=1);
    }
    
    // Top is at depth - 1, nth is at depth - 1 - n
    let idx_top = (stack.depth - 1) * 2;
    let idx_n = (stack.depth - 1 - n) * 2;
    
    local top_low: felt = [stack.data + idx_top];
    local top_high: felt = [stack.data + idx_top + 1];
    local n_low: felt = [stack.data + idx_n];
    local n_high: felt = [stack.data + idx_n + 1];
    
    // Copy to new array with swapped positions
    let (new_data) = alloc();
    let top_pos = stack.depth - 1;
    let n_pos = stack.depth - 1 - n;
    _copy_with_swap_simple(stack.data, new_data, stack.depth, top_pos, n_pos,
                           top_low, top_high, n_low, n_high, 0);
    
    return (new_stack=Stack(data=new_data, depth=stack.depth, top_idx=stack.depth), err=0);
}

func _copy_with_swap_simple(
    src: felt*, dst: felt*, depth: felt, top_pos: felt, n_pos: felt,
    top_low: felt, top_high: felt, n_low: felt, n_high: felt,
    i: felt
) {
    if (i == depth) {
        return ();
    }
    
    let idx = i * 2;
    
    if (i == top_pos) {
        // Put n's value at top position
        assert [dst + idx] = n_low;
        assert [dst + idx + 1] = n_high;
        return _copy_with_swap_simple(src, dst, depth, top_pos, n_pos, top_low, top_high, n_low, n_high, i + 1);
    }
    
    if (i == n_pos) {
        // Put top's value at n position
        assert [dst + idx] = top_low;
        assert [dst + idx + 1] = top_high;
        return _copy_with_swap_simple(src, dst, depth, top_pos, n_pos, top_low, top_high, n_low, n_high, i + 1);
    }
    
    // Normal copy
    assert [dst + idx] = [src + idx];
    assert [dst + idx + 1] = [src + idx + 1];
    return _copy_with_swap_simple(src, dst, depth, top_pos, n_pos, top_low, top_high, n_low, n_high, i + 1);
}

// Duplicate nth item to top (1 = top, 2 = second, etc.) - O(1)
func stack_dup{range_check_ptr}(stack: Stack, n: felt) -> (new_stack: Stack, err: felt) {
    let has_enough = is_le(n, stack.depth);
    if (has_enough == 0) {
        return (new_stack=stack, err=1);
    }
    
    // nth from top is at position (depth - n)
    let idx = (stack.depth - n) * 2;
    let low = [stack.data + idx];
    let high = [stack.data + idx + 1];
    
    let (new_stack) = stack_push(stack, Uint256(low=low, high=high));
    return (new_stack=new_stack, err=0);
}

// Reset stack to empty state
func stack_reset(stack: Stack) -> (new_stack: Stack) {
    let (new_data) = alloc();
    return (new_stack=Stack(data=new_data, depth=0, top_idx=0));
}
