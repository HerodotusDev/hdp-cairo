from starkware.starknet.common.new_syscalls import (
    CALL_CONTRACT_SELECTOR,
    CallContractRequest,
    CallContractResponse,
    RequestHeader,
    ResponseHeader,
    FailureReason,
)
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.starknet.core.os.builtins import BuiltinPointers
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_label_location
from src.utils.chain_info import chain_id_to_layout
from src.memorizers.evm.state_access import EvmStateAccess, EvmStateAccessType, EvmDecoderTarget
from src.utils.chain_info import Layout
from src.contract_bootloader.sha256_utils import finalize_sha256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

struct ExecutionInfo {
    selector: felt,
}

// Represents the execution context during the execution of contract code.
struct ExecutionContext {
    entry_point_type: felt,
    calldata_size: felt,
    calldata: felt*,
    // Additional information about the execution.
    execution_info: ExecutionInfo*,
}

const SHA256_PROCESS_BLOCK_SELECTOR = 'Sha256ProcessBlock';

// Represents 256 bits of a SHA256 state (8 felts each containing 32 bits).
struct Sha256State {
    s0: felt,
    s1: felt,
    s2: felt,
    s3: felt,
    s4: felt,
    s5: felt,
    s6: felt,
    s7: felt,
}

// Represents 512 bits of a SHA256 input (16 felts each containing 32 bits).
struct Sha256Input {
    s0: felt,
    s1: felt,
    s2: felt,
    s3: felt,
    s4: felt,
    s5: felt,
    s6: felt,
    s7: felt,
    s8: felt,
    s9: felt,
    s10: felt,
    s11: felt,
    s12: felt,
    s13: felt,
    s14: felt,
    s15: felt,
}

struct Sha256ProcessBlock {
    input: Sha256Input,
    in_state: Sha256State,
    out_state: Sha256State,
}

struct Sha256ProcessBlockRequest {
    state_ptr: Sha256State*,
    input_start: Sha256Input*,
}

struct Sha256ProcessBlockResponse {
    state_ptr: Sha256State*,
}


// Executes the system calls in syscall_ptr.
// The signature of the function 'call_execute_syscalls' must match this function's signature.
//
// Arguments:
// execution_context - The execution context in which the system calls need to be executed.
// syscall_ptr_end - a pointer to the end of the syscall segment.
func execute_syscalls{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    syscall_ptr: felt*,
    builtin_ptrs: BuiltinPointers*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt***,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}(execution_context: ExecutionContext*, syscall_ptr_end: felt*) {
    if (syscall_ptr == syscall_ptr_end) {
        return ();
    }

    tempvar selector = [syscall_ptr];

    if (selector == SHA256_PROCESS_BLOCK_SELECTOR) {
        execute_sha256_process_block();
        return execute_syscalls(
            execution_context=execution_context, 
            syscall_ptr_end=syscall_ptr_end
        );
    }

    assert selector = CALL_CONTRACT_SELECTOR;
    execute_call_contract(caller_execution_context=execution_context);

    return execute_syscalls(execution_context=execution_context, syscall_ptr_end=syscall_ptr_end);
}

func abstract_memorizer_handler{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    jmp abs func_ptr;
}

// Executes a syscall that calls another contract.
func execute_call_contract{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    syscall_ptr: felt*,
    builtin_ptrs: BuiltinPointers*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt***,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}(caller_execution_context: ExecutionContext*) {
    alloc_locals;
    let request_header = cast(syscall_ptr, RequestHeader*);
    let syscall_ptr = syscall_ptr + RequestHeader.SIZE;

    let call_contract_request = cast(syscall_ptr, CallContractRequest*);
    let syscall_ptr = syscall_ptr + CallContractRequest.SIZE;

    let response_header = cast(syscall_ptr, ResponseHeader*);
    let syscall_ptr = syscall_ptr + ResponseHeader.SIZE;

    let call_contract_response = cast(syscall_ptr, CallContractResponse*);
    let syscall_ptr = syscall_ptr + CallContractResponse.SIZE;

    let state_access_type = call_contract_request.contract_address;
    let field = call_contract_request.selector;

    let layout = chain_id_to_layout(call_contract_request.calldata_start[2]);
    let output_ptr = call_contract_response.retdata_start;

    if (layout == Layout.EVM) {
        with output_ptr {
            let output_len = EvmStateAccess.read_and_decode(
                params=call_contract_request.calldata_start + 2,
                state_access_type=state_access_type,
                field=field,
                decoder_target=EvmDecoderTarget.UINT256,
            );

            return ();
        }
    }

    if (layout == Layout.STARKNET) {
        %{ print("Caught Starknet syscall") %}
        assert 1 = 0;

        return ();
    }

    // Unknown DictId
    assert 1 = 0;

    return ();
}

func execute_sha256_process_block{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    syscall_ptr: felt*,
    builtin_ptrs: BuiltinPointers*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt***,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}() {
    alloc_locals;
    
    let request_header = cast(syscall_ptr, RequestHeader*);
    let syscall_ptr = syscall_ptr + RequestHeader.SIZE;

    let request = cast(syscall_ptr, Sha256ProcessBlockRequest*);
    let syscall_ptr = syscall_ptr + Sha256ProcessBlockRequest.SIZE;

    let response_header = cast(syscall_ptr, ResponseHeader*);
    let syscall_ptr = syscall_ptr + ResponseHeader.SIZE;

    let response = cast(syscall_ptr, Sha256ProcessBlockResponse*);
    let syscall_ptr = syscall_ptr + Sha256ProcessBlockResponse.SIZE;

    let (block_ptr_start: felt*) = alloc();

    memcpy(block_ptr_start, request.input_start, Sha256Input.SIZE);    
    memcpy(block_ptr_start + Sha256Input.SIZE, request.state_ptr, Sha256State.SIZE);
    memcpy(block_ptr_start + Sha256Input.SIZE + Sha256State.SIZE, response.state_ptr, Sha256State.SIZE);
    
    let block_ptr_end = block_ptr_start + Sha256Input.SIZE + Sha256State.SIZE + Sha256State.SIZE;

    finalize_sha256(
        sha256_ptr_start=block_ptr_start, sha256_ptr_end=block_ptr_end
    );

    return ();
}

// Returns a failure response with a single felt.
@known_ap_change
func write_failure_response{syscall_ptr: felt*}(remaining_gas: felt, failure_felt: felt) {
    let response_header = cast(syscall_ptr, ResponseHeader*);
    // Advance syscall pointer to the response body.
    let syscall_ptr = syscall_ptr + ResponseHeader.SIZE;

    // Write the response header.
    assert [response_header] = ResponseHeader(gas=remaining_gas, failure_flag=1);

    let failure_reason: FailureReason* = cast(syscall_ptr, FailureReason*);
    // Advance syscall pointer to the next syscall.
    let syscall_ptr = syscall_ptr + FailureReason.SIZE;

    // Write the failure reason.
    tempvar start = failure_reason.start;
    assert start[0] = failure_felt;
    assert failure_reason.end = start + 1;
    return ();
}
