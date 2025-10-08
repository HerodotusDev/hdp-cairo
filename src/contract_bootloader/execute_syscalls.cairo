from starkware.starknet.common.new_syscalls import (
    CALL_CONTRACT_SELECTOR,
    CallContractRequest,
    CallContractResponse,
    FailureReason,
    KECCAK_SELECTOR,
    KeccakRequest,
    KeccakResponse,
    RequestHeader,
    ResponseHeader,
)
from starkware.cairo.common.builtin_keccak.keccak import (
    KECCAK_FULL_RATE_IN_WORDS,
)
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak as keccak
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_builtins import (
    BitwiseBuiltin,
    EcOpBuiltin,
    HashBuiltin,
    ModBuiltin,
    PoseidonBuiltin,
    SignatureBuiltin,
)
from starkware.starknet.core.os.builtins import BuiltinPointers
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_label_location
from src.utils.chain_info import chain_id_to_layout
from src.memorizers.evm.state_access import EvmStateAccess, EvmStateAccessType
from src.memorizers.starknet.state_access import (
    StarknetStateAccess,
    StarknetStateAccessType,
    StarknetDecoderTarget,
)
from src.utils.chain_info import Layout
from src.memorizers.injected_state.memorizer import InjectedStateMemorizer, InjectedStateHashParams

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
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
    syscall_ptr: felt*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
    injected_state_memorizer: DictAccess*,
}(execution_context: ExecutionContext*, syscall_ptr_end: felt*) {
    if (syscall_ptr == syscall_ptr_end) {
        return ();
    }

    let selector = [syscall_ptr];

    if (selector == CALL_CONTRACT_SELECTOR) {
        execute_call_contract(caller_execution_context=execution_context);
        return execute_syscalls(
            execution_context=execution_context, syscall_ptr_end=syscall_ptr_end
        );
    }

    if (selector == KECCAK_SELECTOR) {
        execute_keccak(caller_execution_context=execution_context);
        return execute_syscalls(
            execution_context=execution_context, syscall_ptr_end=syscall_ptr_end
        );
    }

    // Unknown selector
    assert 1 = 0;

    return execute_syscalls(execution_context=execution_context, syscall_ptr_end=syscall_ptr_end);
}

func abstract_memorizer_handler{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    jmp abs func_ptr;
}

// Executes a syscall that calls another contract.
func execute_call_contract{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
    syscall_ptr: felt*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
    injected_state_memorizer: DictAccess*,
}(caller_execution_context: ExecutionContext*) {
    alloc_locals;
    let request_header = cast(syscall_ptr, RequestHeader*);
    let syscall_ptr = syscall_ptr + RequestHeader.SIZE;

    let request = cast(syscall_ptr, CallContractRequest*);
    let syscall_ptr = syscall_ptr + CallContractRequest.SIZE;

    let response_header = cast(syscall_ptr, ResponseHeader*);
    let syscall_ptr = syscall_ptr + ResponseHeader.SIZE;

    let response = cast(syscall_ptr, CallContractResponse*);
    let syscall_ptr = syscall_ptr + CallContractResponse.SIZE;

    // Debug Contract does not need to be executed
    if (request.contract_address == 'debug') {
        return ();
    }

    // arbitrary_type Contract does not need to be executed
    if (request.contract_address == 'arbitrary_type') {
        return ();
    }

    // TODO!!!
    if (request.contract_address == 'injected_state') {
        let call_handler_id = request.selector;

        if (call_handler_id == 0) {
            tempvar key_trie_label = request.calldata_start[2];

            let memorizer_key = InjectedStateHashParams.label{poseidon_ptr=poseidon_ptr}(
                label=key_trie_label
            );
            let (trie_root_ptr) = InjectedStateMemorizer.get(key=memorizer_key);

            assert [trie_root_ptr] = response.retdata_start[0];
            return ();
        }

        if (call_handler_id == 1) {
            tempvar key_trie_label = request.calldata_start[2];
            tempvar key_key = request.calldata_start[3];

            let memorizer_key = InjectedStateHashParams.label{poseidon_ptr=poseidon_ptr}(
                label=key_trie_label
            );
            let (trie_root_ptr) = InjectedStateMemorizer.get(key=memorizer_key);

            let memorizer_key_inclusion = InjectedStateHashParams.read_inclusion{
                poseidon_ptr=poseidon_ptr
            }(label=key_trie_label, root=[trie_root_ptr], value=key_key);
            let memorizer_key_non_inclusion = InjectedStateHashParams.read_non_inclusion{
                poseidon_ptr=poseidon_ptr
            }(label=key_trie_label, root=[trie_root_ptr], value=key_key);

            let (value_inclusion) = InjectedStateMemorizer.get(key=memorizer_key_inclusion);
            let (value_non_inclusion) = InjectedStateMemorizer.get(key=memorizer_key_non_inclusion);

            let exists = response.retdata_start[1];
            if (exists == 1) {
                assert [value_inclusion] = response.retdata_start[0];
                assert cast(value_non_inclusion, felt) = -1;
            } else {
                assert cast(value_inclusion, felt) = -1;
                assert [value_non_inclusion] = response.retdata_start[0];
            }

            return ();
        }

        if (call_handler_id == 2) {
            tempvar key_trie_label = request.calldata_start[2];
            tempvar key_key = request.calldata_start[3];

            let label_memorizer_key = InjectedStateHashParams.label{poseidon_ptr=poseidon_ptr}(
                label=key_trie_label
            );
            let (trie_root_ptr) = InjectedStateMemorizer.get(key=label_memorizer_key);

            let memorizer_key = InjectedStateHashParams.write{poseidon_ptr=poseidon_ptr}(
                label=key_trie_label, root=[trie_root_ptr], value=key_key
            );
            let (new_root_ptr) = InjectedStateMemorizer.get(key=memorizer_key);

            InjectedStateMemorizer.add(key=label_memorizer_key, data=new_root_ptr);
            return ();
        }

        // Unknown DictId
        assert 1 = 0;

        return ();
    }

    let state_access_type = request.contract_address;
    let field = request.selector;
    let layout = chain_id_to_layout(request.calldata_start[2]);
    let output_ptr = response.retdata_start;

    if (layout == Layout.EVM) {
        with output_ptr {
            EvmStateAccess.read_and_decode(
                params=request.calldata_start + 2, state_access_type=state_access_type, field=field
            );

            return ();
        }
    }

    if (layout == Layout.STARKNET) {
        with output_ptr {
            StarknetStateAccess.read_and_decode(
                params=request.calldata_start + 2,
                state_access_type=state_access_type,
                field=field,
                decoder_target=0,
                as_be=1,
            );
        }

        return ();
    }

    // Unknown DictId
    assert 1 = 0;

    return ();
}

// Executes a syscall that calls another contract.
func execute_keccak{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
    syscall_ptr: felt*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}(caller_execution_context: ExecutionContext*) {
    alloc_locals;
    let request_header = cast(syscall_ptr, RequestHeader*);
    let syscall_ptr = syscall_ptr + RequestHeader.SIZE;

    let request = cast(syscall_ptr, KeccakRequest*);
    let syscall_ptr = syscall_ptr + KeccakRequest.SIZE;

    let response_header = cast(syscall_ptr, ResponseHeader*);
    let syscall_ptr = syscall_ptr + ResponseHeader.SIZE;

    let response = cast(syscall_ptr, KeccakResponse*);
    let syscall_ptr = syscall_ptr + KeccakResponse.SIZE;

    tempvar input_start = request.input_start;
    tempvar input_end = request.input_end;
    tempvar len = input_end - input_start;

    let (res) = keccak(inputs=input_start, n_bytes=len);

    assert response.result_low = res.low;
    assert response.result_high = res.high;

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
