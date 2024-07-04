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
from contract_bootloader.contract_bootloader import run_contract_bootloader, compute_program_hash
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.memcpy import memcpy

func compute_contract{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    header_dict: DictAccess*,
    block_tx_dict: DictAccess*,
    block_receipt_dict: DictAccess*,
    pow2_array: felt*,
}(inputs: felt*, inputs_len: felt) -> (result: Uint256, program_hash: felt) {
    alloc_locals;
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

    let (program_hash_volotile) = compute_program_hash(
        bytecode_length=compiled_class.bytecode_length-1, bytecode_ptr=compiled_class.bytecode_ptr
    );
    local program_hash = program_hash_volotile;

    %{
        vm_load_program(
            compiled_class.get_runnable_program(entrypoint_builtins=[]),
            ids.compiled_class.bytecode_ptr
        )
    %}

    local calldata: felt* = nondet %{ segments.add() %};

    assert calldata[0] = nondet %{ ids.header_dict.address_.segment_index %};
    assert calldata[1] = nondet %{ ids.header_dict.address_.offset %};
    assert calldata[2] = nondet %{ ids.account_dict.address_.segment_index %};
    assert calldata[3] = nondet %{ ids.account_dict.address_.offset %};
    memcpy(dst=calldata + 4, src=inputs, len=inputs_len);
    let calldata_size = inputs_len + 4;

    with account_dict, storage_dict, header_dict, block_tx_dict, block_receipt_dict, pow2_array {
        let (retdata_size, retdata) = run_contract_bootloader(
            compiled_class=compiled_class, calldata_size=calldata_size, calldata=calldata, dry_run=0
        );
    }

    assert retdata_size = 2;
    local result: Uint256 = Uint256(low=retdata[0], high=retdata[1]);
    return (result=result, program_hash=program_hash);
}
