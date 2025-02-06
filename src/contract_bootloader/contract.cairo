from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)
from src.contract_bootloader.contract_class.compiled_class import CompiledClass, compiled_class_hash
from src.contract_bootloader.contract_bootloader import (
    run_contract_bootloader,
    compute_program_hash,
)
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc

func compute_contract{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt***,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}() -> (result: Uint256, program_hash: felt) {
    alloc_locals;

    local params_len: felt;
    let (params) = alloc();
    local compiled_class: CompiledClass*;

    %{ ids.compiled_class = segments.gen_arg(get_compiled_class_struct(compiled_class=compiled_class)) %}

    %{
        ids.params_len = len(params)
        segments.write_arg(ids.params, [param.value for param in params])
    %}

    let (builtin_costs: felt*) = alloc();
    assert builtin_costs[0] = 0;
    assert builtin_costs[1] = 0;
    assert builtin_costs[2] = 0;
    assert builtin_costs[3] = 0;
    assert builtin_costs[4] = 0;

    assert compiled_class.bytecode_ptr[compiled_class.bytecode_length] = 0x208b7fff7fff7ffe;
    assert compiled_class.bytecode_ptr[compiled_class.bytecode_length + 1] = cast(
        builtin_costs, felt
    );

    let (local program_hash) = compiled_class_hash(compiled_class=compiled_class);

    %{ print("program_hash", hex(ids.program_hash)) %}

    %{
        vm_load_program(
            compiled_class.get_runnable_program(entrypoint_builtins=[]),
            ids.compiled_class.bytecode_ptr
        )
    %}

    tempvar calldata: felt* = nondet %{ segments.add() %};

    assert calldata[0] = nondet %{ ids.evm_memorizer.address_.segment_index %};
    assert calldata[1] = nondet %{ ids.evm_memorizer.address_.offset %};
    assert calldata[2] = nondet %{ ids.starknet_memorizer.address_.segment_index %};
    assert calldata[3] = nondet %{ ids.starknet_memorizer.address_.offset %};

    memcpy(dst=calldata + 4, src=params, len=params_len);
    let calldata_size = 4 + params_len;

    with evm_memorizer, starknet_memorizer, pow2_array {
        let (retdata_size, retdata) = run_contract_bootloader(
            compiled_class=compiled_class, calldata_size=calldata_size, calldata=calldata, dry_run=0
        );
    }

    tempvar low;
    tempvar high;

    if (retdata_size == 0) {
        low = 0x0;
        high = 0x0;
    }
    if (retdata_size == 1) {
        low = retdata[0];
        high = 0x0;
    }
    if (retdata_size == 2) {
        low = retdata[0];
        high = retdata[1];
    }

    local result: Uint256 = Uint256(low=low, high=high);

    %{ print(f"Task Result: {hex(ids.result.high * 2 ** 128 + ids.result.low)}") %}

    return (result=result, program_hash=program_hash);
}
