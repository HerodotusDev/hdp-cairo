%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon

from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from contract_bootloader.contract_class.compiled_class import CompiledClass
from contract_bootloader.contract_bootloader import run_contract_bootloader, compute_program_hash

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

    %{
        from src.objects import Module
        module = Module.Schema().load(program_input)
        inputs = module.inputs
        compiled_class = module.compiled_class
    %}

    local calldata: felt* = nondet %{ segments.add() %};
    local calldata_size: felt;

    %{
        offset = 0
        for input in inputs:
            memory[ids.calldata + offset] = input
            offset +=1
        ids.calldata_size = offset
    %}

    local compiled_class: CompiledClass*;

    // Fetch contract data form hints.
    %{
        from starkware.starknet.core.os.contract_class.compiled_class_hash import create_bytecode_segment_structure
        from contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct

        # Append necessary footer to the bytecode of the contract
        compiled_class.bytecode.append(0x208b7fff7fff7ffe)
        compiled_class.bytecode_segment_lengths[-1] += 1

        bytecode_segment_structure = create_bytecode_segment_structure(
            bytecode=compiled_class.bytecode,
            bytecode_segment_lengths=compiled_class.bytecode_segment_lengths,
            visited_pcs=None,
        )

        cairo_contract = get_compiled_class_struct(
            compiled_class=compiled_class,
            bytecode=bytecode_segment_structure.bytecode_with_skipped_segments()
        )
        ids.compiled_class = segments.gen_arg(cairo_contract)
    %}

    assert compiled_class.bytecode_ptr[compiled_class.bytecode_length] = 0x208b7fff7fff7ffe;
    let (program_hash) = compute_program_hash(
        bytecode_length=compiled_class.bytecode_length, bytecode_ptr=compiled_class.bytecode_ptr
    );

    %{
        vm_load_program(
            compiled_class.get_runnable_program(entrypoint_builtins=[]),
            ids.compiled_class.bytecode_ptr
        )
    %}

    %{
        from contract_bootloader.dryrun_syscall_handler import DryRunSyscallHandler

        if '__dict_manager' not in globals():
                from starkware.cairo.common.dict import DictManager
                __dict_manager = DictManager()

        syscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager)
    %}

    let (retdata_size, retdata) = run_contract_bootloader(
        compiled_class=compiled_class, calldata_size=calldata_size, calldata=calldata
    );

    assert retdata_size = 2;
    let result: Uint256 = Uint256(low=retdata[0], high=retdata[1]);

    %{
        print("program_hash", hex(ids.program_hash))
        print("result.low", hex(ids.result.low))
        print("result.high", hex(ids.result.high))
    %}

    return ();
}