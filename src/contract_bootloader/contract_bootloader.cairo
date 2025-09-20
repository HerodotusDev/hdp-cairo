from starkware.cairo.common.cairo_builtins import (
    BitwiseBuiltin,
    EcOpBuiltin,
    HashBuiltin,
    KeccakBuiltin,
    ModBuiltin,
    PoseidonBuiltin,
    SignatureBuiltin,
)
from starkware.cairo.common.sha256_state import Sha256ProcessBlock
from starkware.cairo.common.cairo_sha256.sha256_utils import finalize_sha256
from starkware.cairo.common.registers import get_fp_and_pc
from src.contract_bootloader.contract_class.compiled_class import CompiledClass
from starkware.starknet.builtins.segment_arena.segment_arena import new_arena, SegmentArenaBuiltin
from starkware.starknet.core.os.builtins import (
    BuiltinEncodings,
    BuiltinParams,
    BuiltinPointers,
    NonSelectableBuiltins,
    BuiltinInstanceSizes,
    SelectableBuiltins,
)
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.starknet.core.os.constants import ENTRY_POINT_TYPE_EXTERNAL
from src.contract_bootloader.execute_entry_point import execute_entry_point
from src.contract_bootloader.execute_syscalls import ExecutionContext, ExecutionInfo
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc

// Loads the programs and executes them.
//
// Hint Arguments:
// compiled_class - contains the contract to execute.
//
// Returns:
// Updated builtin pointers after executing all programs.
// fact_topologies - that corresponds to the tasks (hint variable).
func run_contract_bootloader{
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
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
    injected_state_memorizer: DictAccess*,
}(compiled_class: CompiledClass*, calldata_size: felt, calldata: felt*, dry_run: felt) -> (
    retdata_size: felt, retdata: felt*
) {
    alloc_locals;

    // Prepare builtin pointers.
    let segment_arena_ptr = new_arena();
    let (sha256_ptr: Sha256ProcessBlock*) = alloc();
    // TODO enable and test it.
    // %{ syscall_handler.sha256_segment = ids.sha256_ptr %}

    let (__fp__, _) = get_fp_and_pc();
    local local_builtin_ptrs: BuiltinPointers = BuiltinPointers(
        selectable=SelectableBuiltins(
            pedersen=pedersen_ptr,
            range_check=nondet %{ segments.add() %},
            ecdsa=ecdsa_ptr,
            bitwise=bitwise_ptr,
            ec_op=ec_op_ptr,
            poseidon=poseidon_ptr,
            segment_arena=segment_arena_ptr,
            range_check96=range_check96_ptr,
            add_mod=add_mod_ptr,
            mul_mod=mul_mod_ptr,
        ),
        non_selectable=NonSelectableBuiltins(keccak=keccak_ptr, sha256=sha256_ptr),
    );

    let builtin_ptrs = &local_builtin_ptrs;
    let sha256_ptr_start = builtin_ptrs.non_selectable.sha256;

    local local_builtin_encodings: BuiltinEncodings = BuiltinEncodings(
        pedersen='pedersen',
        range_check='range_check',
        ecdsa='ecdsa',
        bitwise='bitwise',
        ec_op='ec_op',
        poseidon='poseidon',
        segment_arena='segment_arena',
        range_check96='range_check96',
        add_mod='add_mod',
        mul_mod='mul_mod',
    );

    local local_builtin_instance_sizes: BuiltinInstanceSizes = BuiltinInstanceSizes(
        pedersen=HashBuiltin.SIZE,
        range_check=1,
        ecdsa=SignatureBuiltin.SIZE,
        bitwise=BitwiseBuiltin.SIZE,
        ec_op=EcOpBuiltin.SIZE,
        poseidon=PoseidonBuiltin.SIZE,
        segment_arena=SegmentArenaBuiltin.SIZE,
        range_check96=1,
        add_mod=ModBuiltin.SIZE,
        mul_mod=ModBuiltin.SIZE,
    );

    local local_builtin_params: BuiltinParams = BuiltinParams(
        builtin_encodings=&local_builtin_encodings,
        builtin_instance_sizes=&local_builtin_instance_sizes,
    );
    let builtin_params = &local_builtin_params;

    local execution_info: ExecutionInfo = ExecutionInfo(
        selector=0x00e2054f8a912367e38a22ce773328ff8aabf8082c4120bad9ef085e1dbf29a7
    );

    local execution_context: ExecutionContext = ExecutionContext(
        entry_point_type=ENTRY_POINT_TYPE_EXTERNAL,
        calldata_size=calldata_size,
        calldata=calldata,
        execution_info=&execution_info,
    );

    with builtin_ptrs, builtin_params {
        let (retdata_size, retdata) = execute_entry_point(
            compiled_class, &execution_context, dry_run=dry_run
        );
    }

    // TODO enable and test it.
    // Finalize the sha256 segment.
    // finalize_sha256(
    //     sha256_ptr_start=sha256_ptr_start, sha256_ptr_end=builtin_ptrs.non_selectable.sha256
    // );

    return (retdata_size, retdata);
}

// Computes the hash of a program.
// Arguments:
//  * program_data_ptr - the pointer to the program to be hashed.
// Return values:
//  * hash - the computed program hash.
func compute_program_hash{poseidon_ptr: PoseidonBuiltin*}(
    bytecode_length: felt, bytecode_ptr: felt*
) -> (hash: felt) {
    let (hash) = poseidon_hash_many{poseidon_ptr=poseidon_ptr}(
        n=bytecode_length, elements=bytecode_ptr
    );
    return (hash=hash);
}
