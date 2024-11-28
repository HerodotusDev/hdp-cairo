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
from contract_bootloader.contract_class.compiled_class import CompiledClass, compiled_class_hash
from contract_bootloader.contract_bootloader import run_contract_bootloader, compute_program_hash
from starkware.cairo.common.memcpy import memcpy

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

    local inputs_len: felt = 0;
    let (inputs) = alloc();

    %{
        from tools.py.schema import HDPDryRunInput
        compiled_class = HDPDryRunInput.Schema().load(program_input).modules[0].module_class
    %}

    local compiled_class: CompiledClass*;

    // Fetch contract data form hints.
    %{
        from contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct
        ids.compiled_class = segments.gen_arg(get_compiled_class_struct(compiled_class=compiled_class))
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

    let (local evm_memorizer) = default_dict_new(default_value=7);
    let (local starknet_memorizer) = default_dict_new(default_value=7);
    tempvar pow2_array: felt* = nondet %{ segments.add() %};

    %{
        if '__dict_manager' not in globals():
            from starkware.cairo.common.dict import DictManager
            __dict_manager = DictManager()
    %}

    %{
        from contract_bootloader.dryrun_syscall_handler import DryRunSyscallHandler
        syscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager)
    %}

    tempvar calldata: felt* = nondet %{ segments.add() %};

    assert calldata[0] = nondet %{ ids.evm_memorizer.address_.segment_index %};
    assert calldata[1] = nondet %{ ids.evm_memorizer.address_.offset %};
    assert calldata[2] = nondet %{ ids.starknet_memorizer.address_.segment_index %};
    assert calldata[3] = nondet %{ ids.starknet_memorizer.address_.offset %};

    memcpy(dst=calldata + 4, src=inputs, len=inputs_len);
    let calldata_size = 4 + inputs_len;

    let (evm_decoder_ptr: felt***) = alloc();
    let (starknet_decoder_ptr: felt***) = alloc();
    let (evm_key_hasher_ptr: felt**) = alloc();
    let (starknet_key_hasher_ptr: felt**) = alloc();

    with evm_memorizer, starknet_memorizer, pow2_array, evm_decoder_ptr, starknet_decoder_ptr, evm_key_hasher_ptr, starknet_key_hasher_ptr {
        let (retdata_size, retdata) = run_contract_bootloader(
            compiled_class=compiled_class, calldata_size=calldata_size, calldata=calldata, dry_run=1
        );
    }

    assert retdata_size = 2;
    local result: Uint256 = Uint256(low=retdata[0], high=retdata[1]);

    %{
        print("result.low", hex(ids.result.low))
        print("result.high", hex(ids.result.high))
    %}

    return ();
}
