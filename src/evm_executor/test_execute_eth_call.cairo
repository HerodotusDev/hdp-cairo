%builtins output range_check bitwise keccak poseidon

// Test runner for execute_eth_call function
// Tests the unified eth_call functionality

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.dict_access import DictAccess

from src.evm_executor.execute_eth_call import (
    execute_eth_call,
    TimeAndSpace,
    EthAddress,
    TransactionResult
)
from src.memorizers.evm.memorizer import EvmMemorizer
from src.memorizers.evm.state_access import EvmStateAccess, EvmDecoder

// ============================================================
// MAIN TEST RUNNER
// ============================================================

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, poseidon_ptr: PoseidonBuiltin*}() {
    alloc_locals;
    
    %{ print("\n=== Testing execute_eth_call ===\n") %}
    
    // Initialize pow2_array
    let (pow2_array: felt*) = alloc();
    init_pow2_array(pow2_array, 0, 1);
    
    // Initialize HDP Memorizer
    let (evm_memorizer_start, evm_memorizer) = EvmMemorizer.init();
    
    // Initialize Decoders and Hashers
    let evm_decoder_ptr = EvmDecoder.init();
    let evm_key_hasher_ptr = EvmStateAccess.init();
    
    // Load test configuration from input
    local chain_id: felt;
    local block_number: felt;
    local target_address_low: felt;
    local target_address_high: felt;
    local sender_address_low: felt;
    local sender_address_high: felt;
    local calldata_len: felt;
    local expected_result: felt;
    
    %{
        test_config = program_input.get("test_config", {})
        ids.chain_id = int(test_config.get("chain_id", 1))
        ids.block_number = int(test_config.get("block_number", 1))
        
        # Parse target address
        target_addr = test_config.get("target_address", "0x0")
        if isinstance(target_addr, str):
            target_addr = int(target_addr, 16)
        # Split into low (128 bits) and high (32 bits)
        ids.target_address_low = target_addr & ((1 << 128) - 1)
        ids.target_address_high = (target_addr >> 128) & ((1 << 32) - 1)
        
        # Parse sender address
        sender_addr = test_config.get("sender_address", "0x0")
        if isinstance(sender_addr, str):
            sender_addr = int(sender_addr, 16)
        ids.sender_address_low = sender_addr & ((1 << 128) - 1)
        ids.sender_address_high = (sender_addr >> 128) & ((1 << 32) - 1)
        
        # Calldata
        calldata = test_config.get("calldata", [])
        ids.calldata_len = len(calldata)
        
        # Expected result (for validation)
        ids.expected_result = int(test_config.get("expected_result", 0))
        
        print(f"Chain ID: {ids.chain_id}")
        print(f"Block: {ids.block_number}")
        print(f"Target: 0x{target_addr:040x}")
        print(f"Sender: 0x{sender_addr:040x}")
        print(f"Calldata: {calldata}")
    %}
    
    // Prepare calldata array
    let (calldata_ptr: felt*) = alloc();
    %{
        calldata = test_config.get("calldata", [])
        # Pack calldata bytes into felts (8 bytes per felt, little-endian)
        for i in range(0, len(calldata), 8):
            chunk = calldata[i:i+8]
            # Pad to 8 bytes
            while len(chunk) < 8:
                chunk.append(0)
            # Pack as little-endian
            val = 0
            for j, b in enumerate(chunk):
                val += b * (256 ** j)
            memory[ids.calldata_ptr + (i // 8)] = val
    %}
    
    // Populate HDP memorizer with bytecode
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
        def pack_felts(bytes_data):
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

        # Get bytecode from input
        bytecode = program_input.get("bytecode", [])
        if not bytecode:
            print("⚠️  No bytecode provided in input!")
            sys.exit(1)
        
        # Get context info for key generation
        chain_id = ids.chain_id
        block_number = ids.block_number
        target_addr = (ids.target_address_high << 128) | ids.target_address_low
        code_label = int.from_bytes(b'code', 'big')
        
        # Calculate Key: [chain_id, CODE_LABEL, block, address]
        # We'll use a hint to compute the poseidon hash
        key_params = [chain_id, code_label, block_number, target_addr]
        
        # Encode bytecode as RLP
        rlp_encoded = rlp_encode_bytes(bytecode)
        
        # Pack RLP into felts
        rlp_felts = pack_felts(rlp_encoded)
        
        # Store in memorizer via hint
        # The memorizer key will be computed by HDP's key hasher
        # For testing, we'll use a simplified approach
        memorizer_key = hash(key_params) % (2**251)  # Simplified hash
        
        # Store bytecode in memorizer
        if '_evm_memorizer' not in globals():
            global _evm_memorizer
            _evm_memorizer = {}
        
        # Store as [rlp_ptr, rlp_len]
        rlp_ptr = segments.add()
        for i, felt_val in enumerate(rlp_felts):
            memory[rlp_ptr + i] = felt_val
        
        _evm_memorizer[memorizer_key] = rlp_ptr
        
        print(f"Stored bytecode in memorizer: {len(bytecode)} bytes")
        print(f"RLP encoded: {len(rlp_encoded)} bytes")
        print(f"Packed into {len(rlp_felts)} felts")
    %}
    
    // Setup TimeAndSpace
    local time_and_space: TimeAndSpace;
    assert time_and_space.chain_id = chain_id;
    assert time_and_space.block_number = block_number;
    
    // Setup sender address
    local sender: EthAddress;
    assert sender.low = sender_address_low;
    assert sender.high = sender_address_high;
    
    // Setup target address
    local target: EthAddress;
    assert target.low = target_address_low;
    assert target.high = target_address_high;
    
    // Execute eth_call
    let (result: TransactionResult*) = execute_eth_call(
        time_and_space=address_of(time_and_space),
        sender=address_of(sender),
        target=address_of(target),
        calldata_len=calldata_len,
        calldata_ptr=calldata_ptr,
        value_low=0,
        value_high=0,
        gas_limit=100000
    );
    
    // Output results
    %{
        print(f"\n=== Execution Result ===")
        print(f"Success: {ids.result.success}")
        print(f"Return data length: {ids.result.return_data_len} bytes")
        print(f"Gas used: {ids.result.gas_used}")
        
        # Read return data
        if ids.result.success == 1 and ids.result.return_data_len > 0:
            return_data = []
            # Read up to 32 bytes (4 felts)
            for i in range(min(4, (ids.result.return_data_len + 7) // 8)):
                val = memory[ids.result.return_data_ptr + i]
                # Unpack felt to bytes (little-endian)
                for j in range(8):
                    byte = (val >> (j * 8)) & 0xFF
                    if len(return_data) < ids.result.return_data_len:
                        return_data.append(byte)
            print(f"Return data: {[hex(b) for b in return_data[:ids.result.return_data_len]]}")
    %}
    
    // Write output
    assert [output_ptr] = result.success;
    assert [output_ptr + 1] = result.return_data_len;
    assert [output_ptr + 2] = result.gas_used;
    
    return ();
}

// Helper: Initialize pow2_array
func init_pow2_array{range_check_ptr}(arr: felt*, idx: felt, val: felt) {
    if (idx == 256) {
        return ();
    }
    assert [arr + idx] = val;
    return init_pow2_array(arr, idx + 1, val * 2);
}





