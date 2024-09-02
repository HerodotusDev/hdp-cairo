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
from src.memorizers.evm import EvmHeaderMemorizer, EvmAccountMemorizer, EvmStorageMemorizer
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField
from src.decoders.evm.account_decoder import AccountDecoder, AccountField
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder
from src.decoders.decoder import DecoderId, ValueDecoder
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_label_location
from src.chain_info import chain_id_to_memorizer_layout
from src.memorizers.reader import MemorizerReader, MemorizerId

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
    memorizer_handler: felt***,
    decoder_handler: felt***,
}(execution_context: ExecutionContext*, syscall_ptr_end: felt*) {
    if (syscall_ptr == syscall_ptr_end) {
        return ();
    }

    assert [syscall_ptr] = CALL_CONTRACT_SELECTOR;
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
    syscall_ptr: felt*,
    builtin_ptrs: BuiltinPointers*,
    header_dict: DictAccess*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
    memorizer_handler: felt***,
    decoder_handler: felt***,
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

    let memorizer_id = call_contract_request.contract_address;
    let function_id = call_contract_request.selector;

    let memorizer_layout = chain_id_to_memorizer_layout(call_contract_request.calldata_start[2]);
    if (memorizer_id == MemorizerId.HEADER) {
        let (rlp) = MemorizerReader.read{dict_ptr=header_dict, poseidon_ptr=poseidon_ptr}(
            memorizer_layout=memorizer_layout,
            memorizer_id=memorizer_id,
            params=call_contract_request.calldata_start + 2,
        );

        ValueDecoder.decode(
            memorizer_layout,
            memorizer_id,
            rlp,
            function_id,
            1,
            call_contract_response.retdata_start,
        );

        return ();
    }
    if (memorizer_id == MemorizerId.ACCOUNT) {
        let (rlp) = MemorizerReader.read{dict_ptr=account_dict, poseidon_ptr=poseidon_ptr}(
            memorizer_layout=memorizer_layout,
            memorizer_id=memorizer_id,
            params=call_contract_request.calldata_start + 2,
        );

        ValueDecoder.decode(
            memorizer_layout,
            memorizer_id,
            rlp,
            function_id,
            1,
            call_contract_response.retdata_start,
        );

        return ();
    }
    if (memorizer_id == MemorizerId.STORAGE) {
        let (rlp) = MemorizerReader.read{dict_ptr=storage_dict, poseidon_ptr=poseidon_ptr}(
            memorizer_layout=memorizer_layout,
            memorizer_id=memorizer_id,
            params=call_contract_request.calldata_start + 2,
        );

        ValueDecoder.decode(
            memorizer_layout,
            memorizer_id,
            rlp,
            function_id,
            1,
            call_contract_response.retdata_start,
        );

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
