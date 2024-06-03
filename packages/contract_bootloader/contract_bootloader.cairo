%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon

from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)
from starkware.cairo.common.registers import get_fp_and_pc
from contract_bootloader.contract_class.compiled_class import CompiledClass
from starkware.starknet.builtins.segment_arena.segment_arena import new_arena, SegmentArenaBuiltin
from starkware.starknet.core.os.builtins import (
    BuiltinEncodings,
    BuiltinParams,
    BuiltinPointers,
    NonSelectableBuiltins,
    BuiltinInstanceSizes,
    SelectableBuiltins,
    update_builtin_ptrs,
)
from contract_bootloader.execute_entry_point import (
    execute_entry_point,
    ExecutionContext,
    ExecutionInfo,
)
from starkware.starknet.core.os.constants import ENTRY_POINT_TYPE_EXTERNAL

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local compiled_class: CompiledClass*;

    %{
        from contract_bootloader.objects import ContractBootloaderInput
        contract_bootloader_input = ContractBootloaderInput.Schema().load(program_input)
    %}

    // Fetch contract data form hints.
    %{
        from starkware.starknet.core.os.contract_class.compiled_class_hash import create_bytecode_segment_structure
        from contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct

        bytecode_segment_structure = create_bytecode_segment_structure(
            bytecode=contract_bootloader_input.compiled_class.bytecode,
            bytecode_segment_lengths=contract_bootloader_input.compiled_class.bytecode_segment_lengths,
            visited_pcs=None,
        )

        cairo_contract = get_compiled_class_struct(
            compiled_class=contract_bootloader_input.compiled_class,
            bytecode=bytecode_segment_structure.bytecode_with_skipped_segments()
        )
        ids.compiled_class = segments.gen_arg(cairo_contract)
    %}

    assert compiled_class.bytecode_ptr[compiled_class.bytecode_length] = 0x208b7fff7fff7ffe;

    %{
        vm_load_program(
            contract_bootloader_input.compiled_class.get_runnable_program(entrypoint_builtins=[]),
            ids.compiled_class.bytecode_ptr
        )
    %}

    run_contract_bootloader(compiled_class);

    return ();
}

// Loads the programs and executes them.
//
// Hint Arguments:
// compiled_class - contains the contract to execute.
//
// Returns:
// Updated builtin pointers after executing all programs.
// fact_topologies - that corresponds to the tasks (hint variable).
func run_contract_bootloader{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(compiled_class: CompiledClass*) {
    alloc_locals;

    // Prepare builtin pointers.
    let segment_arena_ptr = new_arena();

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
        ),
        non_selectable=NonSelectableBuiltins(keccak=keccak_ptr),
    );
    let builtin_ptrs = &local_builtin_ptrs;

    %{ print("builtin_ptrs.selectable.range_check: ", ids.builtin_ptrs.selectable.range_check) %}

    local local_builtin_encodings: BuiltinEncodings = BuiltinEncodings(
        pedersen='pedersen',
        range_check='range_check',
        ecdsa='ecdsa',
        bitwise='bitwise',
        ec_op='ec_op',
        poseidon='poseidon',
        segment_arena='segment_arena',
    );

    local local_builtin_instance_sizes: BuiltinInstanceSizes = BuiltinInstanceSizes(
        pedersen=HashBuiltin.SIZE,
        range_check=1,
        ecdsa=SignatureBuiltin.SIZE,
        bitwise=BitwiseBuiltin.SIZE,
        ec_op=EcOpBuiltin.SIZE,
        poseidon=PoseidonBuiltin.SIZE,
        segment_arena=SegmentArenaBuiltin.SIZE,
    );

    local local_builtin_params: BuiltinParams = BuiltinParams(
        builtin_encodings=&local_builtin_encodings,
        builtin_instance_sizes=&local_builtin_instance_sizes,
    );
    let builtin_params = &local_builtin_params;

    local calldata: felt*;
    %{ ids.calldata = segments.add() %}

    assert calldata[0] = 0x3;
    assert calldata[1] = 0x3;
    assert calldata[2] = 0x4;
    assert calldata[3] = 0x5;

    local execution_info: ExecutionInfo = ExecutionInfo(
        selector=0x00e2054f8a912367e38a22ce773328ff8aabf8082c4120bad9ef085e1dbf29a7
    );

    local execution_context: ExecutionContext = ExecutionContext(
        entry_point_type=ENTRY_POINT_TYPE_EXTERNAL,
        calldata_size=4,
        calldata=calldata,
        execution_info=&execution_info,
    );

    with builtin_ptrs, builtin_params {
        let (retdata_size, retdata) = execute_entry_point(compiled_class, &execution_context);
    }

    return ();
}
