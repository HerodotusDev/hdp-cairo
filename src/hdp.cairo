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
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many, poseidon_hash

from src.verifiers.verify import run_state_verification
from src.module import init_module
from src.types import MMRMeta, ComputationalTask, ChainInfo
from src.utils import write_output_ptr

from src.memorizers.evm import (
    EvmHeaderMemorizer,
    EvmAccountMemorizer,
    EvmStorageMemorizer,
    EvmBlockTxMemorizer,
    EvmBlockReceiptMemorizer,
)
from src.memorizers.starknet import StarknetHeaderMemorizer, StarknetStorageSlotMemorizer
from src.memorizers.bare import BareMemorizer, SingleBareMemorizer
from src.memorizer_access import InternalMemorizerReader, InternalValueDecoder, DictId
from src.chain_info import Layout

from packages.eth_essentials.lib.utils import pow2alloc251, write_felt_array_to_dict_keys

from src.tasks.computational import Task
from src.merkle import (
    compute_tasks_root_v1,
    compute_results_root,
    compute_tasks_hash_v2,
    compute_tasks_root_v2,
    compute_results_root_v2,
)
from src.chain_info import fetch_chain_info
from src.tasks.aggregate_functions.contract import compute_contract

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
    run{
        output_ptr=output_ptr,
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        ecdsa_ptr=ecdsa_ptr,
        bitwise_ptr=bitwise_ptr,
        ec_op_ptr=ec_op_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
    }();

    return ();
}

func run{
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

    // MMR Params
    let (mmr_metas: MMRMeta*) = alloc();

    // Memorizers
    let (evm_header_dict, evm_header_dict_start) = EvmHeaderMemorizer.init();
    let (evm_account_dict, evm_account_dict_start) = EvmAccountMemorizer.init();
    let (evm_storage_dict, evm_storage_dict_start) = EvmStorageMemorizer.init();
    let (evm_block_tx_dict, evm_block_tx_dict_start) = EvmBlockTxMemorizer.init();
    let (evm_block_receipt_dict, evm_block_receipt_dict_start) = EvmBlockReceiptMemorizer.init();
    let (starknet_header_dict, starknet_header_dict_start) = StarknetHeaderMemorizer.init();
    let (starknet_storage_slot_dict, starknet_storage_slot_dict_start) = StarknetStorageSlotMemorizer.init();

    // Task Params
    let (tasks: ComputationalTask*) = alloc();
    local tasks_len: felt;

    let (results: Uint256*) = alloc();

    // Misc
    let pow2_array: felt* = pow2alloc251();
    local hdp_version: felt;

    %{
        from tools.py.utils import split_128, count_leading_zero_nibbles_from_hex

        debug_mode = False
        def conditional_print(*args):
            if debug_mode:
                print(*args)

        def hex_to_int(x):
            return int(x, 16)

        def hex_to_int_array(hex_array):
            return [int(x, 16) for x in hex_array]

        def nested_hex_to_int_array(hex_array):
            return [[int(x, 16) for x in y] for y in hex_array]

        # Task and Datalake
        ids.tasks_len = len(program_input['tasks'])

        if program_input["tasks"][0]["type"] == "datalake_compute":
            ids.hdp_version = 1
        elif program_input["tasks"][0]["type"] == "module":
            ids.hdp_version = 2
        else:
            raise ValueError("Invalid HDP version")

        cairo_run_output_path = program_input["cairo_run_output_path"]
    %}

    let (local mmr_metas_len) = run_state_verification{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        keccak_ptr=keccak_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        evm_header_dict=evm_header_dict,
        evm_account_dict=evm_account_dict,
        evm_storage_dict=evm_storage_dict,
        evm_block_tx_dict=evm_block_tx_dict,
        evm_block_receipt_dict=evm_block_receipt_dict,
        starknet_header_dict=starknet_header_dict,
        starknet_storage_slot_dict=starknet_storage_slot_dict,
        mmr_metas=mmr_metas,
    }();
    let memorizer_handler = InternalMemorizerReader.init();
    let decoder_handler = InternalValueDecoder.init();

    let (tasks_root, results_root, results, results_len) = compute_tasks{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        ecdsa_ptr=ecdsa_ptr,
        bitwise_ptr=bitwise_ptr,
        ec_op_ptr=ec_op_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        evm_account_dict=evm_account_dict,
        evm_storage_dict=evm_storage_dict,
        evm_header_dict=evm_header_dict,
        evm_block_tx_dict=evm_block_tx_dict,
        evm_block_receipt_dict=evm_block_receipt_dict,
        pow2_array=pow2_array,
        tasks=tasks,
        memorizer_handler=memorizer_handler,
        decoder_handler=decoder_handler,
    }(hdp_version=hdp_version, tasks_len=tasks_len);

    %{
        print(f"Tasks Root: {hex(ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low)}")
        print(f"Results Root: {hex(ids.results_root.high * 2 ** 128 + ids.results_root.low)}")
    %}

    // Post Verification Checks: Ensure the roots match the expected roots
    %{
        if "result_root" in program_input:
            assert ids.results_root.high * 2 ** 128 + ids.results_root.low  == hex_to_int(program_input["result_root"]), "Expected results root mismatch" 
        if "task_root" in program_input:
            assert ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low  == hex_to_int(program_input["task_root"]), "Expected results root mismatch"
    %}

    %{
        import json

        dictionary = dict()
        dictionary["tasks_root"] = '0x' + (hex(ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low)[2:].zfill(64))
        dictionary["results_root"] = '0x' + (hex(ids.results_root.high * 2 ** 128 + ids.results_root.low)[2:].zfill(64))
        results = list()
        for i in range(ids.results_len):
            results.append('0x' + (hex(memory[ids.results.address_ + i])[2:].zfill(64)))
        dictionary["results"] = results
        with open(cairo_run_output_path, 'w') as json_file:
            json.dump(dictionary, json_file)
    %}

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(evm_header_dict_start, evm_header_dict, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(evm_account_dict_start, evm_account_dict, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(evm_storage_dict_start, evm_storage_dict, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(evm_block_tx_dict_start, evm_block_tx_dict, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(
        evm_block_receipt_dict_start, evm_block_receipt_dict, BareMemorizer.DEFAULT_VALUE
    );
    default_dict_finalize(starknet_header_dict_start, starknet_header_dict, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(starknet_storage_slot_dict_start, starknet_storage_slot_dict, SingleBareMemorizer.DEFAULT_VALUE);
    %{ print("mmr_metas_len: ", ids.mmr_metas_len) %}
    write_output_ptr{output_ptr=output_ptr}(
        mmr_metas=mmr_metas,
        mmr_metas_len=mmr_metas_len,
        tasks_root=tasks_root,
        results_root=results_root,
    );

    return ();
}

// Entrypoint for running the different hdp versions. Either with "classical" v1 approach, or bootloaded custom modules
func compute_tasks{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_account_dict: DictAccess*,
    evm_storage_dict: DictAccess*,
    evm_header_dict: DictAccess*,
    evm_block_tx_dict: DictAccess*,
    evm_block_receipt_dict: DictAccess*,
    pow2_array: felt*,
    tasks: ComputationalTask*,
    memorizer_handler: felt***,
    decoder_handler: felt***,
}(hdp_version: felt, tasks_len: felt) -> (
    tasks_root: Uint256, results_root: Uint256, results: Uint256*, results_len: felt
) {
    alloc_locals;

    let (results: Uint256*) = alloc();

    if (hdp_version == 1) {
        Task.init(tasks_len, 0);
        Task.execute(results=results, tasks_len=tasks_len, index=0);

        let tasks_root = compute_tasks_root_v1{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(tasks=tasks, tasks_len=tasks_len);

        let results_root = compute_results_root{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(tasks=tasks, results=results, tasks_len=tasks_len);

        return (
            tasks_root=tasks_root, results_root=results_root, results=results, results_len=tasks_len
        );
    }

    if (hdp_version == 2) {
        // Task Params
        local encoded_task_len: felt;
        local task_bytes_len: felt;
        let (encoded_task) = alloc();

        local inputs_len: felt;
        let (inputs) = alloc();

        %{
            from tools.py.schema import Module, CompiledClass, Visibility

            # Load the module input
            module_input = Module.Schema().load(program_input["tasks"][0]["context"])

            compiled_class = module_input.module_class

            ids.task_bytes_len = module_input.task_bytes_len
            ids.encoded_task_len = len(module_input.encoded_task)

            segments.write_arg(ids.encoded_task, module_input.encoded_task)

            inputs = [input.value for input in module_input.inputs]
            ids.inputs_len = len(inputs)
            segments.write_arg(ids.inputs, inputs)
        %}

        let (local module_task) = init_module(encoded_task);

        %{ assert [int(input.value) for input in module_input.inputs if input.visibility == Visibility.PUBLIC] == [int(memory[ids.module_task.module_inputs + i]) for i in range(ids.module_task.module_inputs_len)] %}

        let (result, program_hash) = compute_contract(inputs, inputs_len);

        assert results[0] = result;

        %{
            target_result = hex(ids.result.high * 2 ** 128 + ids.result.low)
            print(f"Task Result: {target_result}")
        %}

        let task_hash = compute_tasks_hash_v2{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(encoded_task=encoded_task, task_bytes_len=task_bytes_len);

        let (flipped_task_hash) = uint256_reverse_endian(task_hash);

        let tasks_root = compute_tasks_root_v2{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(task_hash=flipped_task_hash);

        let results_root = compute_results_root_v2{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(task_hash=flipped_task_hash, result=result);

        return (tasks_root=tasks_root, results_root=results_root, results=results, results_len=1);
    }

    assert 1 = 0;
    return (tasks_root=Uint256(0, 0), results_root=Uint256(0, 0), results=results, results_len=0);
}
