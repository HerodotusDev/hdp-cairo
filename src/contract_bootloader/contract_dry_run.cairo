%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon range_check96 add_mod mul_mod

from starkware.cairo.common.cairo_builtins import (
    BitwiseBuiltin,
    EcOpBuiltin,
    HashBuiltin,
    KeccakBuiltin,
    ModBuiltin,
    PoseidonBuiltin,
    SignatureBuiltin,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak_felts
from src.contract_bootloader.contract_class.compiled_class import CompiledClass, compiled_class_hash
from src.contract_bootloader.contract_bootloader import (
    run_contract_bootloader,
    compute_program_hash,
)
from starkware.cairo.common.memcpy import memcpy
from src.utils.merkle import compute_merkle_root
from src.utils.utils import felt_array_to_uint256s

struct DryRunOutput {
    module_hash: felt,
    result: Uint256,
}

func main{
    output_ptr: felt*,
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
}() {
    alloc_locals;

    %{
        dry_run_input = HDPDryRunInput.Schema().load(program_input)
        params = dry_run_input.params
        compiled_class = dry_run_input.compiled_class
    %}

    let (public_inputs) = alloc();
    %{ segments.write_arg(ids.public_inputs, public_inputs) %}
    tempvar public_inputs_len: felt = nondet %{ len(public_inputs) %};

    let (private_inputs) = alloc();
    %{ segments.write_arg(ids.private_inputs, private_inputs) %}
    tempvar private_inputs_len: felt = nondet %{ len(private_inputs) %};

    let (module_inputs) = alloc();
    memcpy(dst=module_inputs, src=public_inputs, len=public_inputs_len);
    memcpy(dst=module_inputs + public_inputs_len, src=private_inputs, len=private_inputs_len);
    tempvar module_inputs_len: felt = public_inputs_len + private_inputs_len;

    local compiled_class: CompiledClass*;
    %{ ids.compiled_class = segments.gen_arg(get_compiled_class_struct(compiled_class=compiled_class)) %}

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

    let (local module_hash) = compiled_class_hash(compiled_class=compiled_class);

    %{ print("module_hash", hex(ids.module_hash)) %}

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
            __dict_manager = DictManager()
    %}

    %{ syscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager) %}

    tempvar calldata: felt* = nondet %{ segments.add() %};

    assert calldata[0] = nondet %{ ids.evm_memorizer.address_.segment_index %};
    assert calldata[1] = nondet %{ ids.evm_memorizer.address_.offset %};
    assert calldata[2] = nondet %{ ids.starknet_memorizer.address_.segment_index %};
    assert calldata[3] = nondet %{ ids.starknet_memorizer.address_.offset %};

    memcpy(dst=calldata + 4, src=module_inputs, len=module_inputs_len);
    let calldata_size = 4 + module_inputs_len;

    let (evm_decoder_ptr: felt**) = alloc();
    let (starknet_decoder_ptr: felt***) = alloc();
    let (evm_key_hasher_ptr: felt**) = alloc();
    let (starknet_key_hasher_ptr: felt**) = alloc();

    with evm_memorizer, starknet_memorizer, pow2_array, evm_decoder_ptr, starknet_decoder_ptr, evm_key_hasher_ptr, starknet_key_hasher_ptr {
        let (retdata_size, retdata) = run_contract_bootloader(
            compiled_class=compiled_class, calldata_size=calldata_size, calldata=calldata, dry_run=1
        );
    }

    let (task_hash_preimage) = alloc();
    assert task_hash_preimage[0] = module_hash;
    memcpy(dst=task_hash_preimage + 1, src=public_inputs, len=public_inputs_len);
    tempvar task_hash_preimage_len: felt = 1 + public_inputs_len;

    let (taskHash) = keccak_felts(task_hash_preimage_len, task_hash_preimage);

    assert[output_ptr] = taskHash.low;
    assert[output_ptr + 1] = taskHash.high;
    let output_ptr = output_ptr + 2;
    
    let (leafs: Uint256*) = alloc();
    felt_array_to_uint256s(counter=retdata_size, retdata=retdata, leafs=leafs);
    let output_root = compute_merkle_root(leafs, retdata_size);
    assert[output_ptr + 0] = output_root.low;
    assert[output_ptr + 1] = output_root.high;
    let output_ptr = output_ptr + 2;

    return ();
}
