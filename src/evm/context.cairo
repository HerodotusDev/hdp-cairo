// Execution Context for EVM Calls
// Holds the environment for the current execution frame

from starkware.cairo.common.uint256 import Uint256

struct EvmExecutionContext {
    // Block context
    chain_id: felt,
    block_number: felt,
    timestamp: felt,
    
    // Message context
    contract_address: felt,  // address(this)
    caller: felt,            // msg.sender
    origin: felt,            // tx.origin
    value: Uint256,          // msg.value
    
    // Gas
    gas_limit: felt,
    
    // Flags
    read_only: felt,         // 1 if STATICCALL
    
    // Depth tracking (to prevent infinite recursion if not gas limited)
    depth: felt,
}

func context_new(
    chain_id: felt,
    block_number: felt,
    timestamp: felt,
    contract_address: felt,
    caller: felt,
    origin: felt,
    value: Uint256,
    gas_limit: felt,
    read_only: felt,
    depth: felt
) -> (ctx: EvmExecutionContext) {
    return (ctx=EvmExecutionContext(
        chain_id=chain_id,
        block_number=block_number,
        timestamp=timestamp,
        contract_address=contract_address,
        caller=caller,
        origin=origin,
        value=value,
        gas_limit=gas_limit,
        read_only=read_only,
        depth=depth
    ));
}
