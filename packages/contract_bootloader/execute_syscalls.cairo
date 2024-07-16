from starkware.starknet.common.new_syscalls import (
    CALL_CONTRACT_SELECTOR,
    CallContractRequest,
    CallContractResponse,
    RequestHeader,
    ResponseHeader,
    FailureReason,
)
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.starknet.core.os.builtins import BuiltinPointers
from src.memorizer import HeaderMemorizer, AccountMemorizer
from src.decoders.header_decoder import HeaderDecoder
from src.decoders.account_decoder import AccountDecoder, AccountField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess

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
    syscall_ptr: felt*,
    builtin_ptrs: BuiltinPointers*,
    header_dict: DictAccess*,
    account_dict: DictAccess*,
    pow2_array: felt*,
}(execution_context: ExecutionContext*, syscall_ptr_end: felt*) {
    if (syscall_ptr == syscall_ptr_end) {
        return ();
    }

    assert [syscall_ptr] = CALL_CONTRACT_SELECTOR;
    execute_call_contract(caller_execution_context=execution_context);

    return execute_syscalls(execution_context=execution_context, syscall_ptr_end=syscall_ptr_end);
}

namespace MemorizerId {
    const HEADER = 0;
    const ACCOUNT = 1;
}

namespace HeaderMemorizerFunctionId {
    const GET_PARENT = 0;
    const GET_UNCLE = 1;
    const GET_COINBASE = 2;
    const GET_STATE_ROOT = 3;
    const GET_TRANSACTION_ROOT = 4;
    const GET_RECEIPT_ROOT = 5;
    const GET_BLOOM = 6;
    const GET_DIFFICULTY = 7;
    const GET_NUMBER = 8;
    const GET_GAS_LIMIT = 9;
    const GET_GAS_USED = 10;
    const GET_TIMESTAMP = 11;
    const GET_EXTRA_DATA = 12;
    const GET_MIX_HASH = 13;
    const GET_NONCE = 14;
    const GET_BASE_FEE_PER_GAS = 15;
    const GET_WITHDRAWALS_ROOT = 16;
    const GET_BLOB_GAS_USED = 17;
    const GET_EXCESS_BLOB_GAS = 18;
    const GET_PARENT_BEACON_BLOCK_ROOT = 19;
}

namespace AccountMemorizerFunctionId {
    const GET_BALANCE = 0;
}

// Executes a syscall that calls another contract.
func execute_call_contract{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    syscall_ptr: felt*,
    builtin_ptrs: BuiltinPointers*,
    header_dict: DictAccess*,
    account_dict: DictAccess*,
    pow2_array: felt*,
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

    let memorizerId = call_contract_request.contract_address;
    let functionId = call_contract_request.selector;

    if (memorizerId == MemorizerId.ACCOUNT) {
        if (functionId == AccountMemorizerFunctionId.GET_BALANCE) {
            assert 2 + 3 = call_contract_request.calldata_end -
                call_contract_request.calldata_start;
            assert 2 = call_contract_response.retdata_end - call_contract_response.retdata_start;

            let (rlp) = AccountMemorizer.get(
                chain_id=call_contract_request.calldata_start[2],
                block_number=call_contract_request.calldata_start[3],
                address=call_contract_request.calldata_start[4],
            );
            let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.BALANCE);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }

        // Unknown AccountMemorizerFunctionId
        assert 1 = 0;
    }

    // Unknown MemorizerId
    assert 1 = 0;

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
