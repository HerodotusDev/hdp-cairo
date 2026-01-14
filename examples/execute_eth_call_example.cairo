// Example: Using execute_eth_call to call a contract function
// This demonstrates how to use the unified eth_call functionality

%builtins output range_check bitwise keccak poseidon

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.evm_executor.execute_eth_call import (
    execute_eth_call,
    TimeAndSpace,
    EthAddress,
    TransactionResult
)

// Example: Call getConstantNumber() on HPECT1 contract
func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    pow2_array: felt*
}() {
    alloc_locals;
    
    // Initialize HDP components
    // (In real usage, these would be passed from HDP bootloader)
    let evm_decoder_ptr = EvmDecoder.init();
    let evm_key_hasher_ptr = EvmStateAccess.init();
    
    // Setup execution parameters
    local time_and_space: TimeAndSpace;
    assert time_and_space.chain_id = 1;  // Ethereum mainnet
    assert time_and_space.block_number = 19000000;
    
    local sender: EthAddress;
    assert sender.low = 0x946f7cc10fb0a6dc70860b6cf55ef2c722cc7e1a;
    assert sender.high = 0;
    
    local target: EthAddress;
    // HPECT1 contract address
    assert target.low = 0xe5d5bc62cf36fb14efd8c32238c5d39b15bbffd1;
    assert target.high = 0;
    
    // Prepare calldata: getConstantNumber() selector
    // Function signature: getConstantNumber() -> uint256
    // Selector: keccak256("getConstantNumber()")[:4] = 0x9dfcf569
    let (calldata_ptr: felt*) = alloc();
    assert [calldata_ptr] = 0x9dfcf569;
    let calldata_len = 4;
    
    // Execute the call
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
    
    // Check result
    if (result.success == 1) {
        // Success - read return data
        let return_data = result.return_data_ptr;
        let return_len = result.return_data_len;
        
        // Return data is 32 bytes (uint256)
        // Value should be 2137 (0x0859)
        let value_low = [return_data + 30];  // Last 2 bytes
        let value_high = [return_data + 31];
        
        // Output result
        assert [output_ptr] = result.success;
        assert [output_ptr + 1] = return_len;
        assert [output_ptr + 2] = value_low;
        assert [output_ptr + 3] = value_high;
    } else {
        // Execution failed
        assert [output_ptr] = 0;
    }
    
    return ();
}





