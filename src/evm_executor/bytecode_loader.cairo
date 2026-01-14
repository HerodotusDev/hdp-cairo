from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.memorizers.evm.memorizer import EvmPackParams
from src.memorizers.evm.state_access import EvmStateAccess, EvmStateAccessType

from starkware.cairo.common.math_cmp import is_le

// Load bytecode for a given contract address from EvmMemorizer
func load_bytecode{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    pow2_array: felt*
}(
    chain_id: felt, block_number: felt, contract_address: felt
) -> (bytecode: felt*, bytecode_len: felt) {
    alloc_locals;
    
    // Optimisation: Precompiled contracts (1-9) have no bytecode
    // We avoid the expensive DB lookup and potential decoding errors
    let is_precompile = is_le(contract_address, 9);
    if (is_precompile != 0) {
        if (contract_address != 0) {
             let (empty_code: felt*) = alloc();
             return (bytecode=empty_code, bytecode_len=0);
        }
    }

    // 1. Pack params for CODE key
    let (params, params_len) = EvmPackParams.code(chain_id, block_number, contract_address);
    
    // 2. Fetch and Decode
    let (bytecode: felt*) = alloc();
    local bytecode_len: felt;

    // Bridge: Cast KeccakBuiltin* to felt* for HDP compatibility
    let keccak_ptr_felt = cast(keccak_ptr, felt*);
    
    // We must bind the implicit with the expected name for the call
    local real_code: felt*;
    with keccak_ptr_felt {
         let (len) = EvmStateAccess.read_and_decode{keccak_ptr=keccak_ptr_felt, output_ptr=bytecode}(
            params=params, 
            state_access_type=EvmStateAccessType.CODE, 
            field=0
        );
        
        // CodeDecoder returns [bytecode_ptr, bytecode_len] in the output_ptr
        if (len == 2) {
            let bytecode_ptr = cast(bytecode[0], felt*);
            let real_len = bytecode[1];
            assert real_code = bytecode_ptr;
            assert bytecode_len = real_len;
        } else {
            // No code or unexpected format
            assert bytecode_len = 0;
            assert real_code = bytecode;
        }
    }
    
    // Update the original pointer (assuming HDP advances it correctly or not at all)
    let keccak_ptr = cast(keccak_ptr_felt, KeccakBuiltin*);
    
    return (bytecode=real_code, bytecode_len=bytecode_len);
}
