// Unified execute_eth_call function
// Executes a function call against a contract fetched via HDP

%builtins output range_check bitwise keccak poseidon

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess

from starkware.cairo.common.math_cmp import is_le

from src.evm.stack import Stack, evm_stack_new
from src.evm.memory import Memory, evm_memory_new, evm_memory_load
from src.evm.storage import storage_reset, storage_get_return_offset, storage_get_return_size
from src.evm.interpreter import execute_loop
from src.evm.context import ExecutionContext, context_new
from src.evm_executor.bytecode_loader import load_bytecode
from src.memorizers.evm.state_access import EvmStateAccess, EvmDecoder, EvmStateAccessType

// ============================================================
// STRUCTS
// ============================================================

struct EthAddress {
    low: felt,   // Lower 128 bits
    high: felt,  // Upper 32 bits (in felt)
}

struct TimeAndSpace {
    chain_id: felt,
    block_number: felt,
}

struct TransactionResult {
    success: felt,           // 1 = success, 0 = failure
    return_data_len: felt,   // Length of return data in bytes
    return_data_ptr: felt*,  // Pointer to return data
    gas_used: felt,          // Gas consumed
}

// ============================================================
// MAIN ENTRY POINT: execute_eth_call
// ============================================================

// Execute an eth_call against a contract fetched via HDP
// This is the unified entry point for provable eth calls
func execute_eth_call{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    pow2_array: felt*,
    output_ptr: felt*
}(
    time_and_space: TimeAndSpace*,
    sender: EthAddress*,
    target: EthAddress*,
    calldata_len: felt,
    calldata_ptr: felt*,
    value_low: felt,
    value_high: felt,
    gas_limit: felt
) -> (result: TransactionResult*) {
    alloc_locals;
    
    %{
        print(f"\n=== execute_eth_call ===")
        print(f"Chain ID: {ids.time_and_space.chain_id}")
        print(f"Block: {ids.time_and_space.block_number}")
        print(f"Target: 0x{ids.target.high:032x}{ids.target.low:032x}")
        print(f"Sender: 0x{ids.sender.high:032x}{ids.sender.low:032x}")
        print(f"Calldata: {ids.calldata_len} bytes")
    %}
    
    // Initialize HDP components
    let evm_decoder_ptr = EvmDecoder.init();
    let evm_key_hasher_ptr = EvmStateAccess.init();
    
    // Convert target address from EthAddress to felt
    // EthAddress is 160 bits, we combine low (128 bits) + high (32 bits)
    let target_address = target.low + target.high * (2 ** 128);
    let sender_address = sender.low + sender.high * (2 ** 128);
    
    // Step 1: Load bytecode from HDP memorizer
    // This fetches the verified contract bytecode from on-chain data
    let (bytecode, bytecode_len) = load_bytecode(
        chain_id=time_and_space.chain_id,
        block_number=time_and_space.block_number,
        contract_address=target_address
    );
    
    %{
        print(f"Loaded bytecode: {ids.bytecode_len} bytes")
    %}
    
    // Step 2: Create execution context
    let (evm_ctx) = context_new(
        chain_id=time_and_space.chain_id,
        block_number=time_and_space.block_number,
        timestamp=0,  // Could be passed as parameter
        contract_address=target_address,
        caller=sender_address,
        origin=sender_address,  // For eth_call, origin = caller
        value=Uint256(low=value_low, high=value_high),
        gas_limit=gas_limit,
        read_only=1,  // eth_call is read-only
        depth=0
    );
    
    // Step 3: Initialize stack and memory
    let (stack) = evm_stack_new();
    let (memory) = evm_memory_new();
    
    // Step 4: Reset storage (clean state for this call)
    storage_reset();
    
    // Step 5: Execute EVM bytecode
    // This runs the contract's function with the provided calldata
    let (success, final_pc, final_stack, final_memory, _) = execute_loop(
        ctx=evm_ctx,
        pc=0,
        gas=gas_limit,
        bytecode=bytecode,
        bytecode_len=bytecode_len,
        calldata=calldata_ptr,
        calldata_len=calldata_len,
        stack=stack,
        memory=memory
    );
    
    // Step 6: Extract return data
    let (return_offset) = storage_get_return_offset();
    let (return_size) = storage_get_return_size();
    
    // Allocate space for return data
    let (return_data_ptr: felt*) = alloc();
    
    // Copy return data from memory
    let (return_data_ptr) = extract_return_data(
        memory=final_memory,
        offset=return_offset,
        size=return_size,
        dst=return_data_ptr
    );
    
    // Calculate gas used (simplified - would need proper tracking)
    let gas_used = gas_limit;  // TODO: Track actual gas used
    
    // Create result struct
    let (result: TransactionResult*) = alloc();
    assert result.success = success;
    assert result.return_data_len = return_size;
    assert result.return_data_ptr = return_data_ptr;
    assert result.gas_used = gas_used;
    
    %{
        print(f"Execution result: success={ids.success}, return_size={ids.return_size}")
    %}
    
    return (result=result);
}

// Extract return data from EVM memory
// Copies bytes from memory[offset:offset+size] to dst
func extract_return_data{range_check_ptr}(
    memory: Memory,
    offset: felt,
    size: felt,
    dst: felt*
) -> (result_ptr: felt*) {
    alloc_locals;
    
    if (size == 0) {
        return (result_ptr=dst);
    }
    
    // Load 32-byte word from memory
    let (val) = evm_memory_load(memory, offset);
    
    // Store as [low, high] (2 felts per 32-byte word)
    assert [dst] = val.low;
    assert [dst + 1] = val.high;
    
    // If size <= 32, we're done
    let is_done = is_le(size, 32);
    if (is_done == 1) {
        return (result_ptr=dst);
    }
    
    // Recurse for remaining data (step by 32 bytes)
    let (next_ptr) = extract_return_data(memory, offset + 32, size - 32, dst + 2);
    return (result_ptr=dst);
}

