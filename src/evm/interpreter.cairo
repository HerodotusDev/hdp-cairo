// EVM interpreter using optimized stack and memory

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.dict_access import DictAccess

from src.evm.stack import (
    Stack, stack_push, stack_pop, stack_dup, stack_swap, stack_new
)
from src.evm.memory import (
    Memory, memory_store, memory_load, memory_size,
    memory_new, memory_copy_bytes, memory_load_bytes_to_felt_array
)
from src.evm.storage import (
    storage_load, storage_store, storage_get_returndata_size,
    storage_set_return_data, storage_set_returndata_size,
    storage_get_return_offset, storage_get_return_size,
    storage_set_returndata, storage_copy_returndata
)
from src.evm.context import ExecutionContext, context_new
from src.evm_executor.bytecode_loader import load_bytecode
from src.lib.math_utils import (
    _compute_add, _compute_sub, _compute_mul, _compute_div, _compute_sdiv,
    _compute_mod, _compute_smod, _compute_addmod, _compute_mulmod, _compute_exp,
    _shl256, _shr256, _uint256_lt
)
from src.lib.precompiles import handle_precompile
from src.lib.calldata_utils import load_calldata_word, read_push_value, _calldatacopy_loop, _get_byte
from src.lib.bitwise_utils import uint256_and, uint256_or, uint256_xor

func execute_loop{
    range_check_ptr, 
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*, 
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    evm_storage: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    pow2_array: felt*
}(
    ctx: ExecutionContext,
    pc: felt, gas: felt,
    bytecode: felt*, bytecode_len: felt,
    calldata: felt*, calldata_len: felt,
    stack: Stack, memory: Memory
) -> (success: felt, final_pc: felt, final_stack: Stack, final_memory: Memory, remaining_gas: felt) {
    alloc_locals;
    
    // Out of gas?
    let has_gas = is_le(1, gas);
    if (has_gas == 0) {
        return (success=0, final_pc=pc, final_stack=stack, final_memory=memory, remaining_gas=gas);
    }
    
    // PC out of bounds?
    let pc_valid = is_le(pc + 1, bytecode_len);
    if (pc_valid == 0) {
        return (success=0, final_pc=pc, final_stack=stack, final_memory=memory, remaining_gas=gas);
    }
    
    let opcode = [bytecode + pc];
    
    // Execute one step
    let (new_pc, new_gas, new_stack, new_memory, stopped, success) = execute_opcode(
        ctx, opcode, pc, gas, bytecode, bytecode_len, calldata, calldata_len, stack, memory
    );
    
    if (stopped == 1) {
        return (success=success, final_pc=new_pc, final_stack=new_stack, final_memory=new_memory, remaining_gas=new_gas);
    }
    
    return execute_loop(
        ctx, new_pc, new_gas, bytecode, bytecode_len, calldata, calldata_len, new_stack, new_memory
    );
}

// ============================================================
// OPCODE EXECUTION
// ============================================================




func execute_opcode{
    range_check_ptr, 
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*, 
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    evm_storage: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    pow2_array: felt*
}(
    ctx: ExecutionContext,
    opcode: felt, pc: felt, gas: felt,
    bytecode: felt*, bytecode_len: felt,
    calldata: felt*, calldata_len: felt,
    stack: Stack, memory: Memory
) -> (new_pc: felt, new_gas: felt, new_stack: Stack, new_memory: Memory, stopped: felt, success: felt) {
    alloc_locals;
    
    // ===== STOP (0x00) =====
    if (opcode == 0x00) {
        return (new_pc=pc, new_gas=gas, new_stack=stack, new_memory=memory, stopped=1, success=1);
    }
    
    // ===== ADD (0x01) =====
    if (opcode == 0x01) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Use hint for wrapping 256-bit addition
        let (add_result) = _compute_add(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, add_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SUB (0x03) =====
    // EVM: a - b where a is top of stack
    if (opcode == 0x03) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Wrapping subtraction: a - b
        let (sub_result) = _compute_sub(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, sub_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SDIV (0x05) - Signed division =====
    if (opcode == 0x05) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        if (b.low == 0) {
            if (b.high == 0) {
                let (s3) = stack_push(s2, Uint256(low=0, high=0));
                return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
            }
        }
        // Use hint for proper signed division
        let (sdiv_result) = _compute_sdiv(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, sdiv_result);
        return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SMOD (0x07) - Signed modulo =====
    if (opcode == 0x07) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        if (b.low == 0) {
            if (b.high == 0) {
                let (s3) = stack_push(s2, Uint256(low=0, high=0));
                return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
            }
        }
        // Use hint for proper signed modulo
        let (smod_result) = _compute_smod(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, smod_result);
        return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== PUSH0 (0x5F) =====
    if (opcode == 0x5F) {
        let (s1) = stack_push(stack, Uint256(low=0, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== PUSH1-PUSH32 (0x60-0x7F) =====
    let is_push_lo = is_le(0x60, opcode);
    let is_push_hi = is_le(opcode, 0x7F);
    let is_push = is_push_lo * is_push_hi;
    if (is_push == 1) {
        let n = opcode - 0x5F;  // 1-32 bytes
        // Read n bytes and build Uint256
        let (value) = read_push_value(bytecode, pc + 1, n, 0, Uint256(low=0, high=0));
        let (s1) = stack_push(stack, value);
        return (new_pc=pc+1+n, new_gas=gas-3, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== DUP1-DUP16 (0x80-0x8F) =====
    let is_dup_lo = is_le(0x80, opcode);
    let is_dup_hi = is_le(opcode, 0x8F);
    let is_dup = is_dup_lo * is_dup_hi;
    if (is_dup == 1) {
        let n = opcode - 0x7F;  // 1-16
        let (s1, err) = stack_dup(stack, n);
        if (err == 1) {
            return (new_pc=pc, new_gas=gas, new_stack=stack, new_memory=memory, stopped=1, success=0);
        }
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SWAP1-SWAP16 (0x90-0x9F) =====
    let is_swap_lo = is_le(0x90, opcode);
    let is_swap_hi = is_le(opcode, 0x9F);
    let is_swap = is_swap_lo * is_swap_hi;
    if (is_swap == 1) {
        let n = opcode - 0x8F;  // 1-16
        let (s1, err) = stack_swap(stack, n);
        if (err == 1) {
            return (new_pc=pc, new_gas=gas, new_stack=stack, new_memory=memory, stopped=1, success=0);
        }
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== MSTORE (0x52) =====
    if (opcode == 0x52) {
        let (s1, offset, _) = stack_pop(stack);
        let (s2, value, _) = stack_pop(s1);
        let (m1) = memory_store(memory, offset.low, value);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=m1, stopped=0, success=1);
    }
    
    // ===== MLOAD (0x51) =====
    if (opcode == 0x51) {
        let (s1, offset, _) = stack_pop(stack);
        let (value) = memory_load(memory, offset.low);
        let (s2) = stack_push(s1, value);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== JUMP (0x56) =====
    if (opcode == 0x56) {
        let (s1, dest, _) = stack_pop(stack);
        let dest_ok = is_le(dest.low + 1, bytecode_len);
        if (dest_ok == 0) {
            return (new_pc=pc, new_gas=gas, new_stack=s1, new_memory=memory, stopped=1, success=0);
        }
        let dest_op = [bytecode + dest.low];
        if (dest_op != 0x5B) {
            return (new_pc=pc, new_gas=gas, new_stack=s1, new_memory=memory, stopped=1, success=0);
        }
        return (new_pc=dest.low, new_gas=gas-8, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== JUMPI (0x57) =====
    if (opcode == 0x57) {
        let (s1, dest, _) = stack_pop(stack);
        let (s2, cond, _) = stack_pop(s1);
        
        if (cond.low == 0) {
            if (cond.high == 0) {
                return (new_pc=pc+1, new_gas=gas-10, new_stack=s2, new_memory=memory, stopped=0, success=1);
            }
        }
        let dest_ok = is_le(dest.low + 1, bytecode_len);
        if (dest_ok == 0) {
            return (new_pc=pc, new_gas=gas, new_stack=s2, new_memory=memory, stopped=1, success=0);
        }
        let dest_op = [bytecode + dest.low];
        if (dest_op != 0x5B) {
            return (new_pc=pc, new_gas=gas, new_stack=s2, new_memory=memory, stopped=1, success=0);
        }
        return (new_pc=dest.low, new_gas=gas-10, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== JUMPDEST (0x5B) =====
    if (opcode == 0x5B) {
        return (new_pc=pc+1, new_gas=gas-1, new_stack=stack, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== POP (0x50) =====
    if (opcode == 0x50) {
        let (s1, _, _) = stack_pop(stack);
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== ISZERO (0x15) =====
    if (opcode == 0x15) {
        let (s1, a, _) = stack_pop(stack);
        if (a.low == 0) {
            if (a.high == 0) {
                let (s2) = stack_push(s1, Uint256(low=1, high=0));
                return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=memory, stopped=0, success=1);
            }
        }
        let (s2) = stack_push(s1, Uint256(low=0, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== EQ (0x14) =====
    if (opcode == 0x14) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        if (a.low == b.low) {
            if (a.high == b.high) {
                let (s3) = stack_push(s2, Uint256(low=1, high=0));
                return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
            }
        }
        let (s3) = stack_push(s2, Uint256(low=0, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== LT (0x10) =====
    if (opcode == 0x10) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // a < b ? Simplified: just compare low for now
        let result = _uint256_lt(a, b);
        let (s3) = stack_push(s2, Uint256(low=result, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== GT (0x11) =====
    if (opcode == 0x11) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // a > b ? -> b < a
        let result = _uint256_lt(b, a);
        let (s3) = stack_push(s2, Uint256(low=result, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== AND (0x16) =====
    if (opcode == 0x16) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Bitwise AND via bitwise builtin
        let (and_result) = uint256_and(a, b);
        let (s3) = stack_push(s2, and_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== OR (0x17) =====
    if (opcode == 0x17) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        let (or_result) = uint256_or(a, b);
        let (s3) = stack_push(s2, or_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SHL (0x1B) =====
    if (opcode == 0x1B) {
        let (s1, shift, _) = stack_pop(stack);
        let (s2, val, _) = stack_pop(s1);
        // Full 256-bit left shift
        let (shl_result) = _shl256(val, shift.low);
        let (s3) = stack_push(s2, shl_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SHR (0x1C) =====
    if (opcode == 0x1C) {
        let (s1, shift, _) = stack_pop(stack);
        let (s2, val, _) = stack_pop(s1);
        let (shr_result) = _shr256(val, shift.low);
        let (s3) = stack_push(s2, shr_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== MUL (0x02) =====
    if (opcode == 0x02) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Full 256-bit multiplication (wrapping)
        let (mul_result) = _compute_mul(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, mul_result);
        return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== DIV (0x04) =====
    if (opcode == 0x04) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Full 256-bit division
        let (div_result) = _compute_div(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, div_result);
        return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== MOD (0x06) =====
    if (opcode == 0x06) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        if (b.low == 0) {
            if (b.high == 0) {
                let (s3) = stack_push(s2, Uint256(low=0, high=0));
                return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
            }
        }
        // Use hint for proper 256-bit modulo
        let (mod_result) = _compute_mod(a.low, a.high, b.low, b.high);
        let (s3) = stack_push(s2, mod_result);
        return (new_pc=pc+1, new_gas=gas-5, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CALLVALUE (0x34) =====
    if (opcode == 0x34) {
        // msg.value from context
        let (s1) = stack_push(stack, ctx.value);
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CALLDATALOAD (0x35) =====
    if (opcode == 0x35) {
        let (s1, offset, _) = stack_pop(stack);
        let (value) = load_calldata_word(calldata, calldata_len, offset.low);
        let (s2) = stack_push(s1, value);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CALLDATASIZE (0x36) =====
    if (opcode == 0x36) {
        let (s1) = stack_push(stack, Uint256(low=calldata_len, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== RETURN (0xF3) =====
    if (opcode == 0xF3) {
        // RETURN offset, size
        // EVM spec: pop offset first, then size
        let (s1, offset, _) = stack_pop(stack);
        let (s2, size, _) = stack_pop(s1);
        // Store return data location for later retrieval
        storage_set_return_data(offset.low, size.low);
        return (new_pc=pc, new_gas=gas, new_stack=s2, new_memory=memory, stopped=1, success=1);
    }
    
    // ===== MCOPY (0x5E) =====
    if (opcode == 0x5E) {
        // MCOPY dest, src, length
        let (s1, dest, _) = stack_pop(stack);
        let (s2, src, _) = stack_pop(s1);
        let (s3, length, _) = stack_pop(s2);
        // Simplified implementation: copy word by word (full support would need byte-level operations)
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SLT (0x12) - Signed less than =====
    if (opcode == 0x12) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Simplified: treat as unsigned for now
        let cmp = _uint256_lt(a, b);
        let (s3) = stack_push(s2, Uint256(low=cmp, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SGT (0x13) - Signed greater than =====
    if (opcode == 0x13) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        // Simplified: treat as unsigned for now
        let cmp = _uint256_lt(b, a);
        let (s3) = stack_push(s2, Uint256(low=cmp, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== XOR (0x18) =====
    if (opcode == 0x18) {
        let (s1, a, _) = stack_pop(stack);
        let (s2, b, _) = stack_pop(s1);
        let (xor_result) = uint256_xor(a, b);
        let (s3) = stack_push(s2, xor_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== NOT (0x19) =====
    if (opcode == 0x19) {
        let (s1, a, _) = stack_pop(stack);
        // NOT = XOR with all 1s = 2^256 - 1 - a
        let max_low = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        let max_high = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        let result_low = max_low - a.low;
        let result_high = max_high - a.high;
        let (s2) = stack_push(s1, Uint256(low=result_low, high=result_high));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== BYTE (0x1A) =====
    if (opcode == 0x1A) {
        let (s1, i, _) = stack_pop(stack);
        let (s2, x, _) = stack_pop(s1);
        let (byte_val) = _get_byte(i.low, x.low, x.high);
        let (s3) = stack_push(s2, Uint256(low=byte_val, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== ADDRESS (0x30) =====
    if (opcode == 0x30) {
        // address(this) from context
        // Hint implemented in Rust - see hint_address
        local low: felt;
        local high: felt;
        %{
            ids.low = ids.ctx.contract_address & ((1 << 128) - 1)
            ids.high = ids.ctx.contract_address >> 128
        %}
        let (s1) = stack_push(stack, Uint256(low=low, high=high));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CALLER (0x33) =====
    if (opcode == 0x33) {
        // msg.sender from context
        // Hint implemented in Rust - see hint_caller
        local low: felt;
        local high: felt;
        %{
            ids.low = ids.ctx.caller & ((1 << 128) - 1)
            ids.high = ids.ctx.caller >> 128
        %}
        let (s1) = stack_push(stack, Uint256(low=low, high=high));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CALLDATACOPY (0x37) =====
    if (opcode == 0x37) {
        let (s1, dest_offset, _) = stack_pop(stack);
        let (s2, data_offset, _) = stack_pop(s1);
        let (s3, length, _) = stack_pop(s2);
        // Copy calldata to memory word by word
        let (m1) = _calldatacopy_loop(memory, calldata, calldata_len, dest_offset.low, data_offset.low, length.low);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=m1, stopped=0, success=1);
    }
    
    // ===== CODESIZE (0x38) =====
    if (opcode == 0x38) {
        let (s1) = stack_push(stack, Uint256(low=bytecode_len, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CODECOPY (0x39) =====
    if (opcode == 0x39) {
        let (s1, dest_offset, _) = stack_pop(stack);
        let (s2, code_offset, _) = stack_pop(s1);
        let (s3, length, _) = stack_pop(s2);
        
        // Copy from bytecode array to memory
        let (m1) = _codecopy_loop(memory, bytecode, bytecode_len, dest_offset.low, code_offset.low, length.low);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=m1, stopped=0, success=1);
    }
    
    // ===== GAS (0x5A) =====
    if (opcode == 0x5A) {
        let (s1) = stack_push(stack, Uint256(low=gas, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== PC (0x58) =====
    if (opcode == 0x58) {
        let (s1) = stack_push(stack, Uint256(low=pc, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== MSIZE (0x59) =====
    if (opcode == 0x59) {
        let (msize) = memory_size(memory);
        let (s1) = stack_push(stack, Uint256(low=msize, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== MSTORE8 (0x53) =====
    if (opcode == 0x53) {
        let (s1, offset, _) = stack_pop(stack);
        let (s2, value, _) = stack_pop(s1);
        let byte_val = value.low - (value.low / 256) * 256;  // value % 256
        let (m1) = memory_store(memory, offset.low, Uint256(low=byte_val, high=0));
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s2, new_memory=m1, stopped=0, success=1);
    }
    
    // ===== SLOAD (0x54) =====
    if (opcode == 0x54) {
        let (s1, key, _) = stack_pop(stack);
        // Use HDP-integrated storage with address scope
        let (value) = storage_load(
            ctx=ctx,
            address=ctx.contract_address,
            key_low=key.low,
            key_high=key.high
        );
        let (s2) = stack_push(s1, value);
        return (new_pc=pc+1, new_gas=gas-100, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SSTORE (0x55) =====
    if (opcode == 0x55) {
        if (ctx.read_only != 0) {
             return (new_pc=pc, new_gas=gas, new_stack=stack, new_memory=memory, stopped=1, success=0);
        }
        let (s1, key, _) = stack_pop(stack);
        let (s2, value, _) = stack_pop(s1);
        // Store in hint-based storage with address scope
        storage_store(ctx.contract_address, key.low, key.high, value.low, value.high);
        return (new_pc=pc+1, new_gas=gas-100, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== EXP (0x0A) =====
    if (opcode == 0x0A) {
        let (s1, base, _) = stack_pop(stack);
        let (s2, exp, _) = stack_pop(s1);
        let (exp_result) = _compute_exp(base.low, base.high, exp.low, exp.high);
        let (s3) = stack_push(s2, exp_result);
        return (new_pc=pc+1, new_gas=gas-10, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== SAR (0x1D) - Arithmetic shift right =====
    if (opcode == 0x1D) {
        let (s1, shift, _) = stack_pop(stack);
        let (s2, val, _) = stack_pop(s1);
        // Simplified: treat as logical shift for positive values
        let (sar_result) = _shr256(val, shift.low);
        let (s3) = stack_push(s2, sar_result);
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== KECCAK256/SHA3 (0x20) =====
    // KECCAK256(offset, size) - computes keccak256 hash of memory[offset:offset+size]
    // Stack: [..., offset, size] -> [..., hash]
    // EVM spec: offset is on top after pushes, so pop offset first, then size
    // (bytecode pushes size first, then offset, so offset is on top)
    if (opcode == 0x20) {
        let (s1, offset, _) = stack_pop(stack);
        let (s2, size, _) = stack_pop(s1);
        
        // Capture in local variables before using in hints
        local offset_val: felt = offset.low;
        local size_val: felt = size.low;
        
        // Read memory and compute keccak256 hash
        // We need to read size_val bytes from memory starting at offset_val
        // Hint implemented in Rust - see hint_sha3
        local hash_low: felt;
        local hash_high: felt;
        %{
            # Read from isolated memory context
            if '_memory_contexts' not in dir():
                global _memory_contexts
                _memory_contexts = {}
            
            mem_id = ids.memory.log
            ctx_mem = _memory_contexts.get(mem_id, {})
            
            offset_val = ids.offset.low
            size_val = ids.size.low
            
            data_bytes = []
            for i in range(size_val):
                data_bytes.append(ctx_mem.get(offset_val + i, 0))
            
            # Compute keccak256 hash
            from starkware.starknet.public.abi import starknet_keccak
            # Safely get the keccak function that starkware already decided to use
            keccak_func = starknet_keccak.__globals__['keccak']
            hash_bytes = keccak_func(bytes(data_bytes))
            
            # Convert to Uint256 (big-endian)
            hash_high = int.from_bytes(hash_bytes[:16], 'big')
            hash_low = int.from_bytes(hash_bytes[16:], 'big')
            
            ids.hash_high = hash_high
            ids.hash_low = hash_low
        %}
        let (s3) = stack_push(s2, Uint256(low=hash_low, high=hash_high));
        return (new_pc=pc+1, new_gas=gas-30, new_stack=s3, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== CALL (0xF1), DELEGATECALL (0xF4), STATICCALL (0xFA) =====
    if (opcode == 0xF1) {
        // CALL gas, addr, value, argsOffset, argsLength, retOffset, retLength
        let (s1, gas_arg, _) = stack_pop(stack);
        let (s2, addr, _) = stack_pop(s1);
        let (s3, value, _) = stack_pop(s2);
        let (s4, argsOffset, _) = stack_pop(s3);
        let (s5, argsLength, _) = stack_pop(s4);
        let (s6, retOffset, _) = stack_pop(s5);
        let (s7, retLength, _) = stack_pop(s6);
        
        if (ctx.read_only != 0) {
            // Revert if sending value in read_only context
            if (value.low != 0) {
                 let (s8) = stack_push(s7, Uint256(low=0, high=0));
                 return (new_pc=pc+1, new_gas=gas, new_stack=s8, new_memory=memory, stopped=0, success=1);
            }
            if (value.high != 0) {
                 let (s8) = stack_push(s7, Uint256(low=0, high=0));
                 return (new_pc=pc+1, new_gas=gas, new_stack=s8, new_memory=memory, stopped=0, success=1);
            }
        }
        
        // Handle precompile
        let is_le_9 = is_le(addr.low, 9);
        let is_ge_1 = is_le(1, addr.low);
        if (is_le_9 * is_ge_1 == 1) {
             let (precompile_result, new_mem) = handle_precompile(addr.low, memory, argsOffset.low, argsLength.low, retOffset.low, retLength.low);
             let (s8) = stack_push(s7, Uint256(low=precompile_result, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s8, new_memory=new_mem, stopped=0, success=1);
        }

        // Recursive Call
        // Check depth limit (arbitrary 1024)
        if (ctx.depth == 1024) {
             let (s8) = stack_push(s7, Uint256(low=0, high=0)); // Fail
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s8, new_memory=memory, stopped=0, success=1);
        }

        // New Context
        // New Context
        let addr_felt = addr.low + addr.high * 2**128;
        let (new_ctx) = context_new(
            chain_id=ctx.chain_id, block_number=ctx.block_number, timestamp=ctx.timestamp,
            contract_address=addr_felt, caller=ctx.contract_address, origin=ctx.origin,
            value=value, gas_limit=gas_arg.low, read_only=ctx.read_only, depth=ctx.depth + 1
        );
        
        // Load Code
        let (child_bytecode, child_bytecode_len) = load_bytecode(ctx.chain_id, ctx.block_number, addr_felt);
        
        // Setup calldata (from argsOffset/Length)
        let (child_calldata: felt*) = alloc();
        memory_load_bytes_to_felt_array(memory, argsOffset.low, argsLength.low, child_calldata);
        
        // Execute
        let (child_stack) = stack_new();
        let (child_mem_init) = memory_new();
        let (child_success, _, _, child_mem, _) = execute_loop(
            new_ctx, 0, gas_arg.low, child_bytecode, child_bytecode_len, child_calldata, argsLength.low, child_stack, child_mem_init
        );
        
        // Copy Return Data
        if (child_success == 1) {
             let (ret_off) = storage_get_return_offset();
             let (ret_size) = storage_get_return_size();
             storage_set_returndata(child_mem, ret_off, ret_size);
             
             let (m_final) = memory_copy_bytes(child_mem, ret_off, memory, retOffset.low, retLength.low);
             let (s8) = stack_push(s7, Uint256(low=1, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s8, new_memory=m_final, stopped=0, success=1);
        } else {
             storage_set_returndata_size(0);
             let (s8) = stack_push(s7, Uint256(low=0, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s8, new_memory=memory, stopped=0, success=1);
        }
    }
    
    if (opcode == 0xF4) {
        // DELEGATECALL gas, addr, argsOffset, argsLength, retOffset, retLength
        let (s1, gas_arg, _) = stack_pop(stack);
        let (s2, addr, _) = stack_pop(s1);
        let (s3, argsOffset, _) = stack_pop(s2);
        let (s4, argsLength, _) = stack_pop(s3);
        let (s5, retOffset, _) = stack_pop(s4);
        let (s6, retLength, _) = stack_pop(s5);
        
        // Handle precompile
        let is_le_9 = is_le(addr.low, 9);
        let is_ge_1 = is_le(1, addr.low);
        if (is_le_9 * is_ge_1 == 1) {
             let (precompile_result, new_mem) = handle_precompile(addr.low, memory, argsOffset.low, argsLength.low, retOffset.low, retLength.low);
             let (s7) = stack_push(s6, Uint256(low=precompile_result, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=new_mem, stopped=0, success=1);
        }
        
        if (ctx.depth == 1024) {
             let (s7) = stack_push(s6, Uint256(low=0, high=0)); // Fail
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=memory, stopped=0, success=1);
        }

        // New Context (Preserve address, caller, value)
        let addr_felt = addr.low + addr.high * 2**128;
        let (new_ctx) = context_new(
            chain_id=ctx.chain_id, block_number=ctx.block_number, timestamp=ctx.timestamp,
            contract_address=ctx.contract_address, caller=ctx.caller, origin=ctx.origin,
            value=ctx.value, gas_limit=gas_arg.low, read_only=ctx.read_only, depth=ctx.depth + 1
        );
        
        let (child_bytecode, child_bytecode_len) = load_bytecode(ctx.chain_id, ctx.block_number, addr_felt);
        let (child_calldata: felt*) = alloc();
        memory_load_bytes_to_felt_array(memory, argsOffset.low, argsLength.low, child_calldata);
        
        let (child_stack) = stack_new();
        let (child_mem_init) = memory_new();
        let (child_success, _, _, child_mem, _) = execute_loop(
            new_ctx, 0, gas_arg.low, child_bytecode, child_bytecode_len, child_calldata, argsLength.low, child_stack, child_mem_init
        );
        
        if (child_success == 1) {
             let (ret_off) = storage_get_return_offset();
             let (ret_size) = storage_get_return_size();
             storage_set_returndata(child_mem, ret_off, ret_size);

             let (m_final) = memory_copy_bytes(child_mem, ret_off, memory, retOffset.low, retLength.low);
             let (s7) = stack_push(s6, Uint256(low=1, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=m_final, stopped=0, success=1);
        } else {
             storage_set_returndata_size(0);
             let (s7) = stack_push(s6, Uint256(low=0, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=memory, stopped=0, success=1);
        }
    }

    if (opcode == 0xFA) {
        // STATICCALL gas, addr, argsOffset, argsLength, retOffset, retLength
        let (s1, gas_arg, _) = stack_pop(stack);
        let (s2, addr, _) = stack_pop(s1);
        let (s3, argsOffset, _) = stack_pop(s2);
        let (s4, argsLength, _) = stack_pop(s3);
        let (s5, retOffset, _) = stack_pop(s4);
        let (s6, retLength, _) = stack_pop(s5);
        
        // Handle precompile
        let is_le_9 = is_le(addr.low, 9);
        let is_ge_1 = is_le(1, addr.low);
        if (is_le_9 * is_ge_1 == 1) {
             let (precompile_result, new_mem) = handle_precompile(addr.low, memory, argsOffset.low, argsLength.low, retOffset.low, retLength.low);
             let (s7) = stack_push(s6, Uint256(low=precompile_result, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=new_mem, stopped=0, success=1);
        }

        if (ctx.depth == 1024) {
             let (s7) = stack_push(s6, Uint256(low=0, high=0)); // Fail
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=memory, stopped=0, success=1);
        }

        // New Context (forced read_only=1)
        let addr_felt = addr.low + addr.high * 2**128;
        let (new_ctx) = context_new(
            chain_id=ctx.chain_id, block_number=ctx.block_number, timestamp=ctx.timestamp,
            contract_address=addr_felt, caller=ctx.contract_address, origin=ctx.origin,
            value=Uint256(0, 0), gas_limit=gas_arg.low, read_only=1, depth=ctx.depth + 1
        );
        
        let (child_bytecode, child_bytecode_len) = load_bytecode(ctx.chain_id, ctx.block_number, addr_felt);
        let (child_calldata: felt*) = alloc();
        memory_load_bytes_to_felt_array(memory, argsOffset.low, argsLength.low, child_calldata);
        
        let (child_stack) = stack_new();
        let (child_mem_init) = memory_new();
        let (child_success, _, _, child_mem, _) = execute_loop(
            new_ctx, 0, gas_arg.low, child_bytecode, child_bytecode_len, child_calldata, argsLength.low, child_stack, child_mem_init
        );
        
        if (child_success == 1) {
             let (ret_off) = storage_get_return_offset();
             let (ret_size) = storage_get_return_size();
             storage_set_returndata(child_mem, ret_off, ret_size);

             let (m_final) = memory_copy_bytes(child_mem, ret_off, memory, retOffset.low, retLength.low);
             let (s7) = stack_push(s6, Uint256(low=1, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=m_final, stopped=0, success=1);
        } else {
             storage_set_returndata_size(0);
             let (s7) = stack_push(s6, Uint256(low=0, high=0));
             return (new_pc=pc+1, new_gas=gas-100, new_stack=s7, new_memory=memory, stopped=0, success=1);
        }
    }
    
    // ===== RETURNDATASIZE (0x3D) =====
    if (opcode == 0x3D) {
        let (ret_size) = storage_get_returndata_size();
        let (s1) = stack_push(stack, Uint256(low=ret_size, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== RETURNDATACOPY (0x3E) =====
    if (opcode == 0x3E) {
        let (s1, d_off, _) = stack_pop(stack);
        let (s2, off, _) = stack_pop(s1);
        let (s3, len, _) = stack_pop(s2);
        
        tempvar rd_destOffset = d_off.low;
        tempvar rd_offset = off.low;
        tempvar rd_length = len.low;
        
        // Copy from global returndata buffer in storage dictionary
        let (m1) = storage_copy_returndata(memory, rd_destOffset, rd_offset, rd_length);
        
        return (new_pc=pc+1, new_gas=gas-3, new_stack=s3, new_memory=m1, stopped=0, success=1);
    }
    
    // ===== ADDMOD (0x08) =====
    if (opcode == 0x08) {
        let (s1, addmod_a, _) = stack_pop(stack);
        let (s2, addmod_b, _) = stack_pop(s1);
        let (s3, addmod_n, _) = stack_pop(s2);
        if (addmod_n.low == 0) {
            if (addmod_n.high == 0) {
                let (s4) = stack_push(s3, Uint256(low=0, high=0));
                return (new_pc=pc+1, new_gas=gas-8, new_stack=s4, new_memory=memory, stopped=0, success=1);
            }
        }
        let (addmod_result) = _compute_addmod(addmod_a.low, addmod_a.high, addmod_b.low, addmod_b.high, addmod_n.low, addmod_n.high);
        let (s4) = stack_push(s3, addmod_result);
        return (new_pc=pc+1, new_gas=gas-8, new_stack=s4, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== MULMOD (0x09) =====
    if (opcode == 0x09) {
        let (s1, mulmod_a, _) = stack_pop(stack);
        let (s2, mulmod_b, _) = stack_pop(s1);
        let (s3, mulmod_n, _) = stack_pop(s2);
        if (mulmod_n.low == 0) {
            if (mulmod_n.high == 0) {
                let (s4) = stack_push(s3, Uint256(low=0, high=0));
                return (new_pc=pc+1, new_gas=gas-8, new_stack=s4, new_memory=memory, stopped=0, success=1);
            }
        }
        let (mulmod_result) = _compute_mulmod(mulmod_a.low, mulmod_a.high, mulmod_b.low, mulmod_b.high, mulmod_n.low, mulmod_n.high);
        let (s4) = stack_push(s3, mulmod_result);
        return (new_pc=pc+1, new_gas=gas-8, new_stack=s4, new_memory=memory, stopped=0, success=1);
    }
    
    // ===== REVERT (0xFD) =====
    if (opcode == 0xFD) {
        return (new_pc=pc, new_gas=gas, new_stack=stack, new_memory=memory, stopped=1, success=0);
    }
    
    // BLOCKHASH (0x40) - mock
    if (opcode == 0x40) {
        let (s1, blocknum, _) = stack_pop(stack);
        // Return mock block hash
        let (s2) = stack_push(s1, Uint256(low=0x12345678DEADBEEF, high=0xCAFEBABE87654321));
        return (new_pc=pc+1, new_gas=gas-20, new_stack=s2, new_memory=memory, stopped=0, success=1);
    }
    
    // COINBASE (0x41) - mock
    if (opcode == 0x41) {
        let (s1) = stack_push(stack, Uint256(low=0xDEAD, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // TIMESTAMP (0x42) - mock
    if (opcode == 0x42) {
        let (s1) = stack_push(stack, Uint256(low=1700000000, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // NUMBER (0x43) - mock block number
    if (opcode == 0x43) {
        let (s1) = stack_push(stack, Uint256(low=18000000, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // DIFFICULTY/PREVRANDAO (0x44) - mock
    if (opcode == 0x44) {
        let (s1) = stack_push(stack, Uint256(low=0x1234, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // GASLIMIT (0x45) - mock
    if (opcode == 0x45) {
        let (s1) = stack_push(stack, Uint256(low=30000000, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // CHAINID (0x46) - mock (1 = mainnet)
    if (opcode == 0x46) {
        let (s1) = stack_push(stack, Uint256(low=1, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // SELFBALANCE (0x47) - mock
    if (opcode == 0x47) {
        let (s1) = stack_push(stack, Uint256(low=0, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // BASEFEE (0x48) - mock
    if (opcode == 0x48) {
        let (s1) = stack_push(stack, Uint256(low=20000000000, high=0));
        return (new_pc=pc+1, new_gas=gas-2, new_stack=s1, new_memory=memory, stopped=0, success=1);
    }
    
    // Unknown opcode - fail
    return (new_pc=pc, new_gas=gas, new_stack=stack, new_memory=memory, stopped=1, success=0);
}

// Helper to copy code to memory
func _codecopy_loop{range_check_ptr}(
    memory: Memory, bytecode: felt*, bytecode_len: felt, 
    dest_offset: felt, code_offset: felt, length: felt
) -> (new_memory: Memory) {
    if (length == 0) {
        return (new_memory=memory);
    }

    // Extract 32-byte word from bytecode
    let (val) = _extract_word_from_bytecode(bytecode, bytecode_len, code_offset);
    
    // Store in memory
    let (m1) = memory_store(memory, dest_offset, val);

    // Check if we are done
    let is_done = is_le(length, 32);
    if (is_done == 1) {
        return (new_memory=m1);
    }

    return _codecopy_loop(m1, bytecode, bytecode_len, dest_offset + 32, code_offset + 32, length - 32);
}

func _extract_word_from_bytecode(bytecode: felt*, bytecode_len: felt, offset: felt) -> (value: Uint256) {
    alloc_locals;
    // Hint implemented in Rust - see hint_extract_word_from_bytecode
    local low: felt;
    local high: felt;
    %{
        # Extract 32 bytes from bytecode array starting at offset
        # Bytecode is an array of felts (one per byte)
        bytecode = [getattr(ids, 'bytecode')[i] for i in range(ids.bytecode_len)]
        
        word_bytes = []
        for i in range(32):
            idx = ids.offset + i
            if idx < ids.bytecode_len:
                word_bytes.append(bytecode[idx])
            else:
                word_bytes.append(0)
        
        # Convert to Uint256
        ids.high = int.from_bytes(word_bytes[:16], 'big')
        ids.low = int.from_bytes(word_bytes[16:], 'big')
    %}
    return (value=Uint256(low=low, high=high));
}


