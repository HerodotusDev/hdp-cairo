from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)
from contract_bootloader.contract_class.compiled_class import CompiledClass
from starkware.cairo.common.uint256 import Uint256
from contract_bootloader.contract_bootloader import run_contract_bootloader

func compute_contract{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(contract_identifier: Uint256) -> Uint256 {
    alloc_locals;
    local compiled_class: CompiledClass*;

    %{
        # from src.objects import Module
        from contract_bootloader.contract_class.contract_class import CompiledClass

        # module = Module.Schema().load(program_input["module"])
        compiled_class = CompiledClass.Schema().load(program_input["module_class"])
    %}

    // Fetch contract data form hints.
    %{
        from starkware.starknet.core.os.contract_class.compiled_class_hash import create_bytecode_segment_structure
        from contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct

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

    %{
        vm_load_program(
            compiled_class.get_runnable_program(entrypoint_builtins=[]),
            ids.compiled_class.bytecode_ptr
        )
    %}

    let (retdata_size, retdata) = run_contract_bootloader(compiled_class);

    %{
        for i in range(ids.retdata_size):
            print(hex(memory[ids.retdata + i]))
    %}

    let value: Uint256 = Uint256(low=0x0, high=0x0);
    return value;
}
