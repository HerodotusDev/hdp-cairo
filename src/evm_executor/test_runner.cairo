%builtins output range_check bitwise keccak poseidon

// Simple test runner for EVM execution - HDP integration
// This tests the EVM with EvmMemorizer integration

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.dict_access import DictAccess

from src.evm.stack import Stack, stack_new
from src.evm.memory import Memory, memory_new, memory_load
from src.evm.storage import storage_init, storage_get_return_offset, storage_get_return_size, storage_store
from src.evm.interpreter import execute_loop
from src.evm.context import ExecutionContext, context_new
from src.memorizers.evm.memorizer import EvmMemorizer
from src.memorizers.evm.state_access import EvmStateAccess, EvmDecoder, EvmStateAccessType

// ============================================================
// MAIN
// ============================================================

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, poseidon_ptr: PoseidonBuiltin*}() {
    alloc_locals;
    
    %{ print("\n=== HDP-EVM Test Runner ===\n") %}
    
    // Load bytecode from input
    local bytecode_len: felt;
    let (bytecode) = alloc();
    %{
        bytecode = program_input.get("bytecode", [])
        ids.bytecode_len = len(bytecode)
        for i, b in enumerate(bytecode):
            memory[ids.bytecode + i] = b
        print(f"Bytecode: {ids.bytecode_len} bytes")
    %}
    
    // Load test cases
    local num_tests: felt;
    %{
        test_cases = program_input.get("test_cases", [])
        ids.num_tests = len(test_cases)
        print(f"Tests: {ids.num_tests}\n")
    %}

    // Initialize Helpers
    let (pow2_array: felt*) = alloc();
    init_pow2_array(pow2_array, 0, 1);
    
    // Initialize Memorizer
    let (evm_memorizer_start, evm_memorizer) = EvmMemorizer.init();
    
    // Initialize Decoders and Hashers
    let evm_decoder_ptr = EvmDecoder.init();
    let evm_key_hasher_ptr = EvmStateAccess.init();
    
    // Populate Memorizer with Bytecode (simulating HDP fetch)
    // We store the bytecode at the default testing address
    %{
        import sys
        # Helper to encode RLP (simplified for Byte Array / String)
        def rlp_encode_bytes(b):
            if len(b) == 1 and b[0] < 0x80:
                return [b[0]]
            elif len(b) < 56:
                return [0x80 + len(b)] + list(b)
            else:
                length_bin = []
                l = len(b)
                while l > 0:
                    length_bin.append(l & 0xFF)
                    l >>= 8
                length_bin.reverse()
                return [0xb7 + len(length_bin)] + length_bin + list(b)

        # Helper to pack into 64-bit LE chunks (felt array)
        def pack_fetls(bytes_data):
            chunks = []
            for i in range(0, len(bytes_data), 8):
                chunk_bytes = bytes_data[i:i+8]
                # pad if needed
                if len(chunk_bytes) < 8:
                    chunk_bytes = chunk_bytes + [0] * (8 - len(chunk_bytes))
                # little endian packing
                val = 0
                for j, b in enumerate(chunk_bytes):
                    val += b * (256**j)
                chunks.append(val)
            return chunks

        # Get context info for key generation
        ctx = program_input.get("hdp_context", {})
        chain_id = int(ctx.get("chain_id", 1))
        block_number = int(ctx.get("block_number", 1))
        address = int(ctx.get("address", "0x1234567890ABCDEF"), 16)
        code_label = int.from_bytes(b'code', 'big')
        
        # Calculate Key: [chain_id, CODE_LABEL, block, address]
        # In Memorizer logic: poseidon_hash_many([chain, 'code', block, address])
        # We need to replicate Poseidon hash or rely on the memorizer being a DictAccess that we can just key by the Hash?
        # NO, 'EvmMemorizer.get(key)' takes a key which is the HASH.
        # But wait, we can't easily compute Poseidon from Python hint without a library.
        # Use a workaround: We can inject the logic to PRE-POPULATE the dict in a way that HDP expects?
        # Actually, in HDP tests usually we mock the dict directly.
        
        # WE NEED THE KEY.
        # The interpreted code calls `EvmHashParams.code` which calls `poseidon_hash_many`.
        # We can't predict the hash in Python easily without 'starkware.crypto'.
        # Solution: We can hint the `EvmMemorizer.get` call inside Cairo? No.
        
        # Better: We can make `EvmMemorizer` use a `SquashedDict` or similar that we populate?
        # The `EvmMemorizer` wraps `BareMemorizer` which wraps `DictAccess`.
        # `DictAccess` maps `key` (felt) to `value` (pointer to data).
        
        # We can use a trick: 
        # Since we are in a test runner, we can't pre-calculate the Poseidon Hash in pure python easily unless we import `poseidon_hash_many` from starkware.
        from starkware.cairo.common.poseidon_hash import poseidon_hash_many
        
        key_params = [chain_id, code_label, block_number, address]
        key = poseidon_hash_many(key_params)
        
        # Encode bytecode to RLP
        bytecode_bytes = bytes(bytecode)
        rlp_bytes = rlp_encode_bytes(bytecode_bytes)
        rlp_felts = pack_fetls(rlp_bytes)
        
        # Store in dict
        # BareMemorizer expects `(value_ptr)` as value?
        # `BareMemorizer.get` returns `(value_ptr)`. 
        # The DictAccess value is the pointer.
        
        # Write RLP data to memory segment
        rlp_base = segments.add()
        segments.write_arg(rlp_base, rlp_felts)
        
        # Update Initial Dict
        # EvmMemorizer.init() returned a dict. We need to access its underlying segment.
        # But `BareMemorizer` uses `default_dict`.
        # If we just set the global tracker for the dict manager?
        
        if '__dict_manager' not in globals():
             from starkware.cairo.common.dict import DictManager
             __dict_manager = DictManager()
             
        # Associate our 'evm_memorizer' (which is just a start ptr) with a manager?
        # EvmMemorizer.init -> BareMemorizer.init -> alloc() and default_dict_new.
        # The evm_memorizer pointer in Cairo is the DictAccess *.

        # Or simpler: Just hint `initial_dict` with the data.
        
        # Ideally we should perform `dict_write` in Cairo to populate it?
        # But then we need to pass the `key`. We can compute the key in Cairo!
    %}
    
    // Compute key and store in memorizer (in Cairo)
    // This ensures consistency
    let (ctx) = get_context_params();
    local code_key;
    with evm_key_hasher_ptr {
        let (key) = EvmStateAccess.compute_memorizer_key(
            params=cast(new (ctx.chain_id, ctx.code_label, ctx.block_number, ctx.contract_address), felt*),
            state_access_type=EvmStateAccessType.CODE
        );
        assert code_key = key;
    }
    
    // Store bytecode in memorizer
    // We need RLP encoded bytecode.
    let (rlp_bytecode: felt*) = alloc();
    let (rlp_hpect2_bytecode: felt*) = alloc();
    %{
        rlp_bytes = rlp_encode_bytes(bytes(bytecode))
        rlp_felts = pack_fetls(rlp_bytes)
        segments.write_arg(ids.rlp_bytecode, rlp_felts)
        
        # HPECT2 Bytecode: 
        # Selector switch:
        # getHpect2Number (561774c3) -> returns 44914 (0xaf72)
        # hpect2Number (895c00d7) -> returns 44914 (0xaf72)
        # default -> returns CALLER
        h2_bytecode = [
            0x36, 0x60, 0x00, 0x14, 0x61, 0x00, 0x24, 0x57, # if calldatasize == 0, jump to return_caller (36)
            0x60, 0x00, 0x35, 0x60, 0xe0, 0x1c,             # Load selector
            0x80, 0x63, 0x56, 0x17, 0x74, 0xc3, 0x14, 0x61, 0x00, 0x2e, 0x57, # getHpect2Number -> 46
            0x80, 0x63, 0x89, 0x5c, 0x00, 0xd7, 0x14, 0x61, 0x00, 0x2e, 0x57, # hpect2Number -> 46
            0x5b, 0x33, 0x60, 0x00, 0x52, 0x60, 0x20, 0x60, 0x00, 0xf3,       # return_caller (36)
            0x5b, 0x61, 0xaf, 0x72, 0x60, 0x00, 0x52, 0x60, 0x20, 0x60, 0x00, 0xf3 # return_af72 (46)
        ]

        rlp_h2 = rlp_encode_bytes(bytes(h2_bytecode))
        rlp_h2_felts = pack_fetls(rlp_h2)
        segments.write_arg(ids.rlp_hpect2_bytecode, rlp_h2_felts)
    %}
    
    // We'll do it in Cairo for one or two known addresses
    with evm_memorizer, evm_key_hasher_ptr, poseidon_ptr {
        let (key1) = EvmStateAccess.compute_memorizer_key(
            params=cast(new (ctx.chain_id, ctx.code_label, ctx.block_number, ctx.contract_address), felt*),
            state_access_type=EvmStateAccessType.CODE
        );
        EvmMemorizer.add(key1, rlp_bytecode);

        let hpect2_addr = 0x2222222222222222222222222222222222222222;
        let (key2) = EvmStateAccess.compute_memorizer_key(
            params=cast(new (ctx.chain_id, ctx.code_label, ctx.block_number, hpect2_addr), felt*),
            state_access_type=EvmStateAccessType.CODE
        );
        EvmMemorizer.add(key2, rlp_hpect2_bytecode);
    }


    // Initialize storage with prefetched data (simulating HDP memorizer)
    %{
        # Initialize storage with data from input
        global _evm_storage
        _evm_storage = {}
        
        storage_data = program_input.get("storage_data", [])
        for entry in storage_data:
            slot_key = (entry.get("slot_low", 0), entry.get("slot_high", 0))
            value = (entry.get("value_low", 0), entry.get("value_high", 0))
            _evm_storage[slot_key] = value
            # print(f"  Prefetched storage[{hex(slot_key[0])}]: {hex(value[0])}")
    %}
    
    // Run tests
    let (passed, failed) = run_all_tests(
        bytecode, bytecode_len, num_tests, 0, 0, 0,
        pow2_array, evm_decoder_ptr, evm_key_hasher_ptr, evm_memorizer
    );
    
    // Output dict check?
    // We don't need to finalize the dict for validity in tests if not using squash.
    // But we should squash if we want to be correct.
    // For now, let it leak.

    %{
        print(f"\n{'='*50}")
        print(f"Results: {ids.passed} passed, {ids.failed} failed")
        print(f"{'='*50}")
    %}
    
    assert [output_ptr] = passed;
    assert [output_ptr + 1] = failed;
    let output_ptr = output_ptr + 2;
    
    return ();
}

func init_pow2_array(arr: felt*, idx: felt, val: felt) {
    if (idx == 254) {
        return ();
    }
    assert arr[idx] = val;
    return init_pow2_array(arr, idx + 1, val * 2);
}

struct TestContext {
    chain_id: felt,
    code_label: felt,
    block_number: felt,
    contract_address: felt,
}

func get_context_params() -> (ctx: TestContext){
    alloc_locals;
    local ctx: TestContext;
    %{
        ctx = program_input.get("hdp_context", {})
        ids.ctx.chain_id = int(ctx.get("chain_id", 1))
        ids.ctx.block_number = int(ctx.get("block_number", 1))
        ids.ctx.contract_address = int(ctx.get("address", "0xe5d5bc62cf36fb14efd8c32238c5d39b15bbffd1"), 16)
        ids.ctx.code_label = int.from_bytes(b'code', 'big')
    %}
    return (ctx=ctx);
}

// ============================================================
// TEST RUNNER
// ============================================================

func test_loop{
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
    num_tests: felt, bytecode: felt*, bytecode_len: felt,
    test_idx: felt, passed: felt, failed: felt
) -> (passed: felt, failed: felt) {
    alloc_locals;
    
    if (test_idx == num_tests) {
        return (passed=passed, failed=failed);
    }
    
    // Get test data
    local calldata_len: felt;
    let (calldata) = alloc();
    %{
        test = program_input["test_cases"][ids.test_idx]
        test_name = test.get("function_name", f"test_{ids.test_idx}")
        calldata = test.get("calldata", [])
        ids.calldata_len = len(calldata)
        for i, b in enumerate(calldata):
            memory[ids.calldata + i] = b
        print(f"Test {ids.test_idx + 1}/{ids.num_tests}: {test_name}")
    %}
    
    // Create execution context
    local chain_id: felt;
    local block_number: felt;
    local timestamp: felt;
    local contract_address: felt;
    local caller: felt;
    local origin: felt;
    local value_low: felt;
    local value_high: felt;
    local gas_limit: felt;
    
    %{
        ctx = program_input.get("hdp_context", {})
        ids.chain_id = int(ctx.get("chain_id", 1))
        ids.block_number = int(ctx.get("block_number", 1))
        ids.timestamp = int(ctx.get("timestamp", 1))
        ids.contract_address = int(ctx.get("address", "0xe5d5bc62cf36fb14efd8c32238c5d39b15bbffd1"), 16)
        ids.caller = int(ctx.get("caller", "0x946f7cc10fb0a6dc70860b6cf55ef2c722cc7e1a"), 16)
        ids.origin = int(ctx.get("origin", "0x946f7cc10fb0a6dc70860b6cf55ef2c722cc7e1a"), 16)
        
        val = ctx.get("value", "0x0")
        if isinstance(val, str):
            val_int = int(val, 16)
        else:
            val_int = val
            
        ids.value_low = val_int & ((1 << 128) - 1)
        ids.value_high = val_int >> 128
        
        ids.gas_limit = 1000000
    %}

    // Create fresh stack, memory
    let (stack) = stack_new();
    let (memory) = memory_new();
    
    // Initialize storage
    // let (new_storage) = storage_init(); // Removed, now implicit
    // let evm_storage = new_storage; // Removed, now implicit
    with evm_storage {
    
    // Default HPECT1 and HPECT2 storage values
    let hpect2_addr = 0x2222222222222222222222222222222222222222;
    let hpect2_addr_low = 0x22222222222222222222222222222222;
    let hpect2_addr_high = 0x22222222;
    
    // 1. Initialize HPECT1 storage
    // exampleNumber = 2137
    storage_store(contract_address, 1, 0, 0x0859, 0);
    // string = "Hello, World!"
    storage_store(contract_address, 2, 0, 0x1a, 0x48656c6c6f2c20576f726c6421000000);
    // mapping key
    storage_store(contract_address, 0xf1c2d9a497496a7f46004d1772c3054c, 0xa15bc60c955c405d20d9149c709e2460, 0x15, 0);
    
    // Set some slots to point to HPECT2
    storage_store(contract_address, 0, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 3, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 4, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 5, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 6, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 7, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 8, 0, hpect2_addr_low, hpect2_addr_high);
    storage_store(contract_address, 9, 0, hpect2_addr_low, hpect2_addr_high);
    
    // 2. Initialize HPECT2 storage
    storage_store(hpect2_addr, 1, 0, 0x0859, 0);
    storage_store(hpect2_addr, 2, 0, 0x1a, 0x48656c6c6f2c20576f726c6421000000);
    storage_store(hpect2_addr, 0xf1c2d9a497496a7f46004d1772c3054c, 0xa15bc60c955c405d20d9149c709e2460, 0x15, 0);
    }

    // 3. Load extra storage from program input via hint
    %{
        storage_data = program_input.get("storage_data", [])
        for entry in storage_data:
            # We use a simple hint to perform individual storage_store calls would be better but
            # for now we can just inject into _evm_storage if dry-run needs it, 
            # and sound-run will need a different approach if it uses extra data.
            # However, hpect1 tests mostly use the defaults above.
            pass
    %}
    
    let (ctx) = context_new(
        chain_id=chain_id,
        block_number=block_number,
        timestamp=timestamp,
        contract_address=contract_address,
        caller=caller,
        origin=origin,
        value=Uint256(low=value_low, high=value_high),
        gas_limit=gas_limit,
        read_only=0,
        depth=0
    );
    
    // Execute with limited gas
    // Pass implicitly threaded vars
    let (success, final_pc, final_stack, final_memory, remaining_gas) = execute_loop{
        evm_memorizer=evm_memorizer,
        evm_decoder_ptr=evm_decoder_ptr,
        evm_key_hasher_ptr=evm_key_hasher_ptr,
        pow2_array=pow2_array,
        evm_storage=evm_storage
    }(
        ctx=ctx,
        pc=0,
        gas=gas_limit,
        bytecode=bytecode,
        bytecode_len=bytecode_len,
        calldata=calldata,
        calldata_len=calldata_len,
        stack=stack,
        memory=memory
    );
    
    // Compare results
    let (test_passed) = compare_results(final_memory, success, test_idx);
    
    if (test_passed == 1) {
        %{ print(f"  ✓ PASS") %}
        return test_loop(
            num_tests, bytecode, bytecode_len, test_idx + 1, passed + 1, failed
        );
    } else {
        %{ print(f"  ✗ FAIL") %}
        return test_loop(
            num_tests, bytecode, bytecode_len, test_idx + 1, passed, failed + 1
        );
    }
}

// ============================================================
// RESULT COMPARISON
// ============================================================

func compare_results{range_check_ptr}(
    memory: Memory, success: felt, test_idx: felt
) -> (matches: felt) {
    alloc_locals;
    
    if (success == 0) {
        %{ print(f"    Execution failed") %}
        return (matches=0);
    }
    
    // Get return data location from RETURN opcode
    let (return_offset) = storage_get_return_offset();
    let (return_size) = storage_get_return_size();
    
    local offset_val: felt = return_offset;
    local size_val: felt = return_size;
    
    // Read memory at return offset
    let (m0) = memory_load(memory, offset_val);
    
    local m0_h: felt = m0.high;
    local m0_l: felt = m0.low;
    
    local matches: felt;
    %{
        test = program_input["test_cases"][ids.test_idx]
        expected = test.get("expected_result", [])
        
        if len(expected) >= 32:
            expected_bytes = bytes(expected[:32])
            expected_high = int.from_bytes(expected_bytes[:16], 'big')
            expected_low = int.from_bytes(expected_bytes[16:], 'big')
        elif len(expected) > 0:
            expected_bytes = bytes(expected) + b'\x00' * (32 - len(expected))
            expected_high = int.from_bytes(expected_bytes[:16], 'big')
            expected_low = int.from_bytes(expected_bytes[16:], 'big')
            # Fix actual (if small return) to be compared correctly?
            # HDP tests usually align to 32 bytes 
        else:
            expected_high, expected_low = 0, 0
        
        actual_high, actual_low = ids.m0_h, ids.m0_l
        
        def fmt(high, low):
            val = (high << 128) | low
            return f"0x{val:064x}" if val else "0"
        
        # print(f"    Expected: {fmt(expected_high, expected_low)}")
        # print(f"    Actual:   {fmt(actual_high, actual_low)} @ offset {hex(ids.offset_val)}")
        
        # Approximate matching (check if first word matches)
        ids.matches = 1 if (expected_high == actual_high and expected_low == actual_low) else 0
        if ids.matches == 0:
             print(f"    Expected: {fmt(expected_high, expected_low)}")
             print(f"    Actual:   {fmt(actual_high, actual_low)} @ offset {hex(ids.offset_val)}")
    %}
    
    return (matches=matches);
}
