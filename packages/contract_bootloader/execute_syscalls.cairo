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
from src.memorizer import HeaderMemorizer, AccountMemorizer, StorageMemorizer
from src.decoders.header_decoder import HeaderDecoder, HeaderField
from src.decoders.account_decoder import AccountDecoder, AccountField
from src.decoders.storage_slot_decoder import StorageSlotDecoder
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
    storage_dict: DictAccess*,
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
    const STORAGE = 2;
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
    const GET_NONCE = 0;
    const GET_BALANCE = 1;
    const GET_STATE_ROOT = 2;
    const GET_CODE_HASH = 3;
}

namespace StorageMemorizerFunctionId {
    const GET_SLOT = 0;
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
    storage_dict: DictAccess*,
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

    if (memorizerId == MemorizerId.HEADER) {
        let (rlp) = HeaderMemorizer.get(
            chain_id=call_contract_request.calldata_start[2],
            block_number=call_contract_request.calldata_start[3],
        );
        if (functionId == HeaderMemorizerFunctionId.GET_PARENT) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.PARENT);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_UNCLE) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.UNCLE);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_COINBASE) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.COINBASE);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_STATE_ROOT) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.STATE_ROOT);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_TRANSACTION_ROOT) {
            let field: Uint256 = HeaderDecoder.get_field(
                rlp=rlp, field=HeaderField.TRANSACTION_ROOT
            );
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_RECEIPT_ROOT) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.RECEIPT_ROOT);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_DIFFICULTY) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.DIFFICULTY);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_NUMBER) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NUMBER);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_GAS_LIMIT) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_LIMIT);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_GAS_USED) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_USED);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_TIMESTAMP) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TIMESTAMP);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_EXTRA_DATA) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.MIX_HASH);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_NONCE) {
            let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NONCE);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == HeaderMemorizerFunctionId.GET_BASE_FEE_PER_GAS) {
            let field: Uint256 = HeaderDecoder.get_field(
                rlp=rlp, field=HeaderField.BASE_FEE_PER_GAS
            );
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }

        // Unknown HeaderMemorizerFunctionId
        assert 1 = 0;

        return ();
    }
    if (memorizerId == MemorizerId.ACCOUNT) {
        let (rlp) = AccountMemorizer.get(
            chain_id=call_contract_request.calldata_start[2],
            block_number=call_contract_request.calldata_start[3],
            address=call_contract_request.calldata_start[4],
        );
        if (functionId == AccountMemorizerFunctionId.GET_NONCE) {
            let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.NONCE);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == AccountMemorizerFunctionId.GET_BALANCE) {
            let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.BALANCE);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == AccountMemorizerFunctionId.GET_STATE_ROOT) {
            let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.STATE_ROOT);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }
        if (functionId == AccountMemorizerFunctionId.GET_CODE_HASH) {
            let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.CODE_HASH);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }

        // Unknown AccountMemorizerFunctionId
        assert 1 = 0;

        return ();
    }
    if (memorizerId == MemorizerId.STORAGE) {
        let (rlp) = StorageMemorizer.get(
            chain_id=call_contract_request.calldata_start[2],
            block_number=call_contract_request.calldata_start[3],
            address=call_contract_request.calldata_start[4],
            storage_slot=Uint256(
                call_contract_request.calldata_start[5], call_contract_request.calldata_start[6]
            ),
        );
        if (functionId == StorageMemorizerFunctionId.GET_SLOT) {
            let field: Uint256 = StorageSlotDecoder.get_word(rlp=rlp);
            let (value) = uint256_reverse_endian(num=field);

            assert call_contract_response.retdata_start[0] = value.low;
            assert call_contract_response.retdata_start[1] = value.high;

            return ();
        }

        // Unknown StorageMemorizerFunctionId
        assert 1 = 0;

        return ();
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
