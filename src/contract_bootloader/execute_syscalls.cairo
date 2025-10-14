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
from starkware.cairo.common.builtin_keccak.keccak import KECCAK_FULL_RATE_IN_WORDS
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak as keccak
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.alloc import alloc
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
from src.utils.debug import print_felt_hex, print_felt, print_string
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

// Helper utilities to adapt builtin-padded 64-bit lanes to raw bytes for cairo_keccak.

 // Extract the byte at a given offset from a buffer of 64-bit-packed words (little-endian within word).
func get_byte_at_offset{range_check_ptr}(base: felt*, pow2_array: felt*, offset: felt) -> (byte: felt) {
    alloc_locals;
    // word_index = offset // 8, in_word_offset = offset % 8
    let (word_index, in_word_offset) = unsigned_div_rem(offset, 8);
    let w = base[word_index];

     // Lanes are little-endian within each 64-bit word in the syscall buffer.
     // shift_bits = in_word_offset * 8
     let shift_bits = in_word_offset * 8;
     let divisor = pow2_array[shift_bits]; // 2 ** shift_bits
     let (q1, _) = unsigned_div_rem(w, divisor);
     let (_, b) = unsigned_div_rem(q1, 256);
     return (byte=b);
}

// Scan from the end of the last block: require trailing 0x80, then zeros, then 0x01.
// Return the index (in bytes from start) of the padding 0x01 byte, which equals the message length.
func find_padding_01_pos{range_check_ptr}(base: felt*, pow2_array: felt*, idx: felt) -> (pos: felt) {
    alloc_locals;
    let (b) = get_byte_at_offset(base, pow2_array, idx);
    if (b == 0) {
        let (pos) = find_padding_01_pos(base, pow2_array, idx - 1);
        return (pos=pos);
    }
    // First non-zero after trailing zeros must be 0x01 (Keccak legacy domain).
    assert b = 1;
    return (pos=idx);
}

 // Recover original (unpadded) message length in bytes from builtin-padded lanes.
func find_message_len_bytes{range_check_ptr}(base: felt*, len_words: felt, pow2_array: felt*) -> (msg_len: felt) {
    alloc_locals;
    let total_bytes = len_words * 8;
    let last_idx = total_bytes - 1;

    // // Debug: print last word and derived indices.
    // tempvar last_word_idx = len_words - 1;
    // print_felt(total_bytes);
    // print_felt(last_idx);
    // print_felt_hex(base[last_word_idx]);

    // Last byte must be 0x80 in the builtin-padded representation.
    let (b_last) = get_byte_at_offset(base, pow2_array, last_idx);
    //print_felt(b_last);
    assert b_last = 128;

    // Move left to find the required 0x01 after a run of zeros.
    let (pos_01) = find_padding_01_pos(base, pow2_array, last_idx - 1);
    // Message length equals index of the 0x01 padding byte.
    return (msg_len=pos_01);
}

// Copy the first n 64-bit words from src to dst.
func copy_prefix_words_loop{range_check_ptr}(src: felt*, dst: felt*, n_words: felt, i: felt) {
    if (i == n_words) {
        return ();
    }
    assert dst[i] = src[i];
    copy_prefix_words_loop(src, dst, n_words, i + 1);
    return ();
}

func copy_prefix_words{range_check_ptr}(src: felt*, dst: felt*, n_words: felt) {
    copy_prefix_words_loop(src, dst, n_words, 0);
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

    // Number of 64-bit lanes in the input (only rate words are provided).
    tempvar len_words = input_end - input_start;
    let (local q, r) = unsigned_div_rem(len_words, KECCAK_FULL_RATE_IN_WORDS);
    // Require whole number of rate blocks.
    assert r = 0;

    // Recover the original unpadded message length (in bytes) from the builtin-padded lanes.
    let (msg_len) = find_message_len_bytes(base=input_start, len_words=len_words, pow2_array=pow2_array);

    // Validate message is an exact number of Uint256 elements (32 bytes each).
    let (n_inputs, rem32) = unsigned_div_rem(msg_len, 32);
    assert rem32 = 0;

    // Materialize the original message as contiguous u64 words for cairo_keccak (little-endian per word).
    // Because keccak_u256s_be_inputs() appends padding words after the message words (last_input_num_bytes=0),
    // the first msg_len/8 words in input_start are exactly the original message words.
    let (n_words, rem8) = unsigned_div_rem(msg_len, 8);
    assert rem8 = 0;
    let (word_buf: felt*) = alloc();
    // First msg_len/8 words are the original message words in little-endian u64.
    copy_prefix_words(src=input_start, dst=word_buf, n_words=n_words);

    // Hash the original message words; cairo_keccak returns a little-endian Uint256.
    let (res) = keccak(inputs=word_buf, n_bytes=msg_len);

    // Output result.
    assert response.result_low = res.low;
    assert response.result_high = res.high;

    //assert 1 = 0;

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
