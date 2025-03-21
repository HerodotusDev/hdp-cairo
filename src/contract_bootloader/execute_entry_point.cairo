from starkware.cairo.common.cairo_builtins import (
    BitwiseBuiltin,
    EcOpBuiltin,
    HashBuiltin,
    KeccakBuiltin,
    ModBuiltin,
    PoseidonBuiltin,
    SignatureBuiltin,
)
from starkware.cairo.builtin_selection.select_input_builtins import select_input_builtins
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.find_element import find_element, search_sorted
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.registers import get_ap
from starkware.cairo.common.dict_access import DictAccess
from starkware.starknet.builtins.segment_arena.segment_arena import (
    SegmentArenaBuiltin,
    validate_segment_arena,
)
from starkware.starknet.core.os.builtins import (
    BuiltinEncodings,
    BuiltinParams,
    BuiltinPointers,
    SelectableBuiltins,
    update_builtin_ptrs,
)
from starkware.starknet.core.os.constants import (
    DEFAULT_ENTRY_POINT_SELECTOR,
    ENTRY_POINT_TYPE_CONSTRUCTOR,
    ENTRY_POINT_TYPE_EXTERNAL,
    ENTRY_POINT_TYPE_L1_HANDLER,
)
from src.contract_bootloader.contract_class.compiled_class import (
    CompiledClass,
    CompiledClassEntryPoint,
)
from src.contract_bootloader.execute_syscalls import ExecutionContext, execute_syscalls
from starkware.cairo.common.registers import get_fp_and_pc

// Represents the arguments pushed to the stack before calling an entry point.
struct EntryPointCallArguments {
    gas_builtin: felt,
    syscall_ptr: felt*,
    calldata_start: felt*,
    calldata_end: felt*,
}

// Represents the values returned by a call to an entry point.
struct EntryPointReturnValues {
    gas_builtin: felt,
    syscall_ptr: felt*,
    // The failure_flag is 0 if the execution succeeded and 1 if it failed.
    failure_flag: felt,
    retdata_start: felt*,
    retdata_end: felt*,
}

// Performs a Cairo jump to the function 'execute_syscalls'.
// This function's signature must match the signature of 'execute_syscalls'.
func call_execute_syscalls{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
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
}(execution_context: ExecutionContext*, syscall_ptr_end: felt*, dry_run: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    if (dry_run == 1) {
        return ();
    }

    execute_syscalls(execution_context=execution_context, syscall_ptr_end=syscall_ptr_end);
    return ();
}

// Returns the CompiledClassEntryPoint, based on 'compiled_class' and 'execution_context'.
func get_entry_point{range_check_ptr}(
    compiled_class: CompiledClass*, execution_context: ExecutionContext*
) -> (entry_point: CompiledClassEntryPoint*) {
    alloc_locals;
    // Get the entry points corresponding to the transaction's type.
    local entry_points: CompiledClassEntryPoint*;
    local n_entry_points: felt;

    tempvar entry_point_type = execution_context.entry_point_type;
    if (entry_point_type == ENTRY_POINT_TYPE_L1_HANDLER) {
        entry_points = compiled_class.l1_handlers;
        n_entry_points = compiled_class.n_l1_handlers;
    } else {
        if (entry_point_type == ENTRY_POINT_TYPE_EXTERNAL) {
            entry_points = compiled_class.external_functions;
            n_entry_points = compiled_class.n_external_functions;
        } else {
            assert entry_point_type = ENTRY_POINT_TYPE_CONSTRUCTOR;
            entry_points = compiled_class.constructors;
            n_entry_points = compiled_class.n_constructors;

            if (n_entry_points == 0) {
                return (entry_point=cast(0, CompiledClassEntryPoint*));
            }
        }
    }

    // The key must be at offset 0.
    static_assert CompiledClassEntryPoint.selector == 0;
    let (entry_point_desc: CompiledClassEntryPoint*, success) = search_sorted(
        array_ptr=cast(entry_points, felt*),
        elm_size=CompiledClassEntryPoint.SIZE,
        n_elms=n_entry_points,
        key=execution_context.execution_info.selector,
    );
    if (success != 0) {
        return (entry_point=entry_point_desc);
    }

    // If the selector was not found, verify that the first entry point is the default entry point,
    // and call it.
    assert_not_zero(n_entry_points);
    assert entry_points[0].selector = DEFAULT_ENTRY_POINT_SELECTOR;
    return (entry_point=&entry_points[0]);
}

// Executes an entry point in a contract.
// The contract entry point is selected based on execution_context.entry_point_type
// and execution_context.execution_info.selector.
//
// Arguments:
// block_context - a global context that is fixed throughout the block.
// execution_context - The context for the current execution.
func execute_entry_point{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
    builtin_ptrs: BuiltinPointers*,
    builtin_params: BuiltinParams*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}(compiled_class: CompiledClass*, execution_context: ExecutionContext*, dry_run: felt) -> (
    retdata_size: felt, retdata: felt*
) {
    alloc_locals;

    let (compiled_class_entry_point: CompiledClassEntryPoint*) = get_entry_point(
        compiled_class=compiled_class, execution_context=execution_context
    );

    if (compiled_class_entry_point == cast(0, CompiledClassEntryPoint*)) {
        // Assert that there is no call data in the case of NOP entry point.
        assert execution_context.calldata_size = 0;
        return (retdata_size=0, retdata=cast(0, felt*));
    }

    let entry_point_offset = compiled_class_entry_point.offset;
    local range_check_ptr = range_check_ptr;
    local contract_entry_point: felt* = compiled_class.bytecode_ptr + entry_point_offset;

    %{
        if '__dict_manager' not in globals():
            __dict_manager = DictManager()
    %}

    %{
        if 'syscall_handler' not in globals():
            syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager)
    %}

    tempvar syscall_ptr: felt* = nondet %{ segments.add() %};

    %{ syscall_handler.set_syscall_ptr(syscall_ptr=ids.syscall_ptr) %}

    let builtin_ptrs: BuiltinPointers* = prepare_builtin_ptrs_for_execute(builtin_ptrs);

    let n_builtins = BuiltinEncodings.SIZE;
    local calldata_start: felt* = execution_context.calldata;
    local calldata_end: felt* = calldata_start + execution_context.calldata_size;
    local entry_point_n_builtins = compiled_class_entry_point.n_builtins;
    local entry_point_builtin_list: felt* = compiled_class_entry_point.builtin_list;
    // Call select_input_builtins to push the relevant builtin pointer arguments on the stack.
    select_input_builtins(
        all_encodings=builtin_params.builtin_encodings,
        all_ptrs=builtin_ptrs,
        n_all_builtins=n_builtins,
        selected_encodings=entry_point_builtin_list,
        n_selected_builtins=entry_point_n_builtins,
    );

    // Use tempvar to pass the rest of the arguments to contract_entry_point().
    let current_ap = ap;
    tempvar args = EntryPointCallArguments(
        gas_builtin=2 ** 64 - 1,
        syscall_ptr=syscall_ptr,
        calldata_start=calldata_start,
        calldata_end=calldata_end,
    );
    static_assert ap == current_ap + EntryPointCallArguments.SIZE;

    %{ vm_enter_scope({'syscall_handler': syscall_handler}) %}
    call abs contract_entry_point;
    %{ vm_exit_scope() %}

    // Retrieve returned_builtin_ptrs_subset.
    // Note that returned_builtin_ptrs_subset cannot be set in a hint because doing so will allow a
    // malicious prover to lie about the storage changes of a valid contract.
    let (ap_val) = get_ap();
    local return_values_ptr: felt* = ap_val - EntryPointReturnValues.SIZE;
    local returned_builtin_ptrs_subset: felt* = return_values_ptr - entry_point_n_builtins;
    local entry_point_return_values: EntryPointReturnValues* = cast(
        return_values_ptr, EntryPointReturnValues*
    );
    assert entry_point_return_values.failure_flag = 0;
    let remaining_gas = entry_point_return_values.gas_builtin;
    let retdata_start = entry_point_return_values.retdata_start;
    let retdata_end = entry_point_return_values.retdata_end;

    let return_builtin_ptrs = update_builtin_ptrs(
        builtin_params=builtin_params,
        builtin_ptrs=builtin_ptrs,
        n_selected_builtins=entry_point_n_builtins,
        selected_encodings=entry_point_builtin_list,
        selected_ptrs=returned_builtin_ptrs_subset,
    );

    // Validate the segment_arena builtin.
    // Note that as the segment_arena pointer points to the first unused element, we need to
    // take segment_arena[-1] to get the actual values.
    tempvar prev_segment_arena = &builtin_ptrs.selectable.segment_arena[-1];
    tempvar current_segment_arena = &return_builtin_ptrs.selectable.segment_arena[-1];
    assert prev_segment_arena.infos = current_segment_arena.infos;
    validate_segment_arena(segment_arena=current_segment_arena);

    let builtin_ptrs = return_builtin_ptrs;

    let selectable_builtins = &builtin_ptrs.selectable;
    let pedersen_ptr = selectable_builtins.pedersen;
    let ecdsa_ptr = selectable_builtins.ecdsa;
    let bitwise_ptr = selectable_builtins.bitwise;
    let ec_op_ptr = selectable_builtins.ec_op;
    let poseidon_ptr = selectable_builtins.poseidon;
    let range_check96_ptr = selectable_builtins.range_check96;
    let add_mod_ptr = selectable_builtins.add_mod;
    let mul_mod_ptr = selectable_builtins.mul_mod;
    let keccak_ptr = builtin_ptrs.non_selectable.keccak;

    // TODO enable and test it.
    // Fill holes in the rc96 segment.
    // %{
    //     rc96_ptr = ids.range_check96_ptr
    //     segment_size = rc96_ptr.offset
    //     base = rc96_ptr - segment_size

    //     for i in range(segment_size):
    //         memory.setdefault(base + i, 0)
    // %}

    with syscall_ptr {
        call_execute_syscalls(
            execution_context=execution_context,
            syscall_ptr_end=entry_point_return_values.syscall_ptr,
            dry_run=dry_run,
        );
    }

    return (retdata_size=retdata_end - retdata_start, retdata=retdata_start);
}

// Prepares the builtin pointer for the execution of an entry point.
// In particular, restarts the SegmentArenaBuiltin struct if it was previously used.
func prepare_builtin_ptrs_for_execute(builtin_ptrs: BuiltinPointers*) -> BuiltinPointers* {
    let selectable_builtins = &builtin_ptrs.selectable;
    tempvar segment_arena_ptr = selectable_builtins.segment_arena;
    tempvar prev_segment_arena = &segment_arena_ptr[-1];

    // If no segment was allocated, we don't need to restart the struct.
    tempvar prev_n_segments = prev_segment_arena.n_segments;
    if (prev_n_segments == 0) {
        return builtin_ptrs;
    }

    assert segment_arena_ptr[0] = SegmentArenaBuiltin(
        infos=&prev_segment_arena.infos[prev_n_segments], n_segments=0, n_finalized=0
    );
    let segment_arena_ptr = &segment_arena_ptr[1];
    return new BuiltinPointers(
        selectable=SelectableBuiltins(
            pedersen=selectable_builtins.pedersen,
            range_check=selectable_builtins.range_check,
            ecdsa=selectable_builtins.ecdsa,
            bitwise=selectable_builtins.bitwise,
            ec_op=selectable_builtins.ec_op,
            poseidon=selectable_builtins.poseidon,
            segment_arena=segment_arena_ptr,
            range_check96=selectable_builtins.range_check96,
            add_mod=selectable_builtins.add_mod,
            mul_mod=selectable_builtins.mul_mod,
        ),
        non_selectable=builtin_ptrs.non_selectable,
    );
}
