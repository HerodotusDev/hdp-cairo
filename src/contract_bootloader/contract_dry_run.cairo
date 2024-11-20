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
from src.contract_bootloader.contract_class.compiled_class import CompiledClass, compiled_class_hash
from src.contract_bootloader.contract_bootloader import (
    run_contract_bootloader,
    compute_program_hash,
)
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

    local inputs_len: felt;
    let (inputs) = alloc();

    %{
        from tools.py.schema import HDPDryRunInput

        print("Starting Dry Run")

        # Load the dry run input
        dry_run_input = HDPDryRunInput.Schema().load(program_input)
        dry_run_output_path = dry_run_input.dry_run_output_path
        # Check if the modules list contains more than one element
        if len(dry_run_input.modules) > 1:
            raise ValueError("The modules list contains more than one element, which is not supported.")

        module_input = dry_run_input.modules[0]

        compiled_class = module_input.module_class

        inputs = [input.value for input in module_input.inputs]
        ids.inputs_len = len(inputs)
        segments.write_arg(ids.inputs, inputs)
    %}

    local compiled_class: CompiledClass*;

    // Fetch contract data form hints.
    %{
        from starkware.starknet.core.os.contract_class.compiled_class_hash import create_bytecode_segment_structure
        from src.contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct

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
    local pow2_array: felt* = nondet %{ segments.add() %};

    %{
        from src.contract_bootloader.dryrun_syscall_handler import DryRunSyscallHandler

        if '__dict_manager' not in globals():
                from starkware.cairo.common.dict import DictManager
                __dict_manager = DictManager()

        syscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager)
    %}

    local calldata: felt* = nondet %{ segments.add() %};

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

    %{
        import json
        list = list()
        dictionary = dict()

        dictionary["fetch_keys"] = syscall_handler.fetch_keys_dict()

        if ids.retdata_size == 2:
            dictionary["result"] = {
                "low": hex(memory[ids.retdata]),
                "high": hex(memory[ids.retdata + 1])
            }
        else:
            high, low = divmod(memory[ids.retdata], 2**128)
            dictionary["result"] = {
                "low": hex(low),
                "high": hex(high)
            }

        dictionary["program_hash"] = hex(ids.program_hash)

        print("Dry Run Result", dictionary["result"])

        list.append(dictionary)

        with open(dry_run_output_path, 'w') as json_file:
            json.dump(list, json_file)
    %}

    return ();
}
