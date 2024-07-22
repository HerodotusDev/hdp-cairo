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

from src.verifiers.verify import run_state_verification
from src.module import init_module
from src.types import MMRMeta, ComputationalTask, ChainInfo
from src.utils import write_output_ptr

from src.memorizer import (
    HeaderMemorizer,
    AccountMemorizer,
    StorageMemorizer,
    BlockTxMemorizer,
    BlockReceiptMemorizer,
)
from packages.eth_essentials.lib.utils import pow2alloc128, write_felt_array_to_dict_keys

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
    local mmr_metas_len: felt;

    // Peaks Dict
    let (local peaks_dict) = default_dict_new(default_value=0);
    tempvar peaks_dict_start = peaks_dict;

    // Memorizers
    let (header_dict, header_dict_start) = HeaderMemorizer.init();
    let (account_dict, account_dict_start) = AccountMemorizer.init();
    let (storage_dict, storage_dict_start) = StorageMemorizer.init();
    let (block_tx_dict, block_tx_dict_start) = BlockTxMemorizer.init();
    let (block_receipt_dict, block_receipt_dict_start) = BlockReceiptMemorizer.init();

    // Task Params
    let (tasks: ComputationalTask*) = alloc();
    local tasks_len: felt;

    let (results: Uint256*) = alloc();

    // Misc
    let pow2_array: felt* = pow2alloc128();
    local chain_id: felt;
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

        def write_mmr_metas(ptr, mmr_metas):
            offset = 0
            ids.mmr_metas_len = len(mmr_metas)
            ids.chain_id = mmr_metas[0]["chain_id"]

            for mmr_meta in mmr_metas:
                assert mmr_meta["chain_id"] == ids.chain_id, "Chain ID mismatch!"
                memory[ptr._reference_value + offset] = mmr_meta["id"]
                memory[ptr._reference_value + offset + 1] = hex_to_int(mmr_meta["root"])
                memory[ptr._reference_value + offset + 2] = mmr_meta["size"]
                memory[ptr._reference_value + offset + 3] = len(mmr_meta["peaks"])
                memory[ptr._reference_value + offset + 4] = segments.gen_arg(hex_to_int_array(mmr_meta["peaks"]))
                memory[ptr._reference_value + offset + 5] = mmr_meta["chain_id"]
                offset += 6

        # MMR Meta
        write_mmr_metas(ids.mmr_metas, program_input["proofs"]['mmr_metas'])

        # Task and Datalake
        ids.tasks_len = len(program_input['tasks'])

        ids.chain_id = 11155111
        if program_input["tasks"][0]["type"] == "datalake_compute":
            ids.hdp_version = 1
        elif program_input["tasks"][0]["type"] == "module":
            ids.hdp_version = 2
        else:
            raise ValueError("Invalid HDP version")

        cairo_run_output_path = program_input["cairo_run_output_path"]
    %}

    // Fetch matching chain info
    let (local chain_info) = fetch_chain_info(chain_id);

    run_state_verification{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        keccak_ptr=keccak_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        peaks_dict=peaks_dict,
        header_dict=header_dict,
        account_dict=account_dict,
        storage_dict=storage_dict,
        block_tx_dict=block_tx_dict,
        block_receipt_dict=block_receipt_dict,
        mmr_metas=mmr_metas,
        chain_info=chain_info,
    }(mmr_metas_len=mmr_metas_len);

    let (tasks_root, results_root, results, results_len) = compute_tasks{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        ecdsa_ptr=ecdsa_ptr,
        bitwise_ptr=bitwise_ptr,
        ec_op_ptr=ec_op_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        account_dict=account_dict,
        storage_dict=storage_dict,
        header_dict=header_dict,
        block_tx_dict=block_tx_dict,
        block_receipt_dict=block_receipt_dict,
        pow2_array=pow2_array,
        tasks=tasks,
        chain_info=chain_info,
    }(hdp_version=hdp_version, tasks_len=tasks_len);

    %{
        print(f"Tasks Root: {hex(ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low)}")
        print(f"Results Root: {hex(ids.results_root.high * 2 ** 128 + ids.results_root.low)}")
    %}

    // Post Verification Checks: Ensure the roots match the expected roots
    %{
        if "task_root" in program_input:
            assert ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low  == hex_to_int(program_input["task_root"]), "Expected results root mismatch"
    %}

    %{
        import json

        dictionary = dict()
        dictionary["tasks_root"] = hex(ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low )
        dictionary["results_root"] = hex(ids.results_root.high * 2 ** 128 + ids.results_root.low)
        results = list()
        for i in range(ids.results_len):
            results.append(memory[ids.results.address_ + i])
        dictionary["results"] = results
        with open(cairo_run_output_path, 'w') as json_file:
            json.dump(dictionary, json_file)
    %}

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(peaks_dict_start, peaks_dict, 0);
    default_dict_finalize(header_dict_start, header_dict, 7);
    default_dict_finalize(account_dict_start, account_dict, 7);
    default_dict_finalize(storage_dict_start, storage_dict, 7);
    default_dict_finalize(block_tx_dict_start, block_tx_dict, 7);
    default_dict_finalize(block_receipt_dict_start, block_receipt_dict, 7);

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
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    header_dict: DictAccess*,
    block_tx_dict: DictAccess*,
    block_receipt_dict: DictAccess*,
    pow2_array: felt*,
    tasks: ComputationalTask*,
    chain_info: ChainInfo,
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

        %{
            from tools.py.schema import CompiledClass

            task = program_input["tasks"][0]["context"]
            compiled_class = CompiledClass.Schema().load(task["module_class"])

            ids.task_bytes_len = task["task_bytes_len"]
            ids.encoded_task_len = len(task["encoded_task"])

            segments.write_arg(ids.encoded_task, hex_to_int_array(task["encoded_task"]))
        %}

        let (local module_task) = init_module(encoded_task, encoded_task_len);

        let (result, program_hash) = compute_contract(module_task.module_inputs, module_task.module_inputs_len);
        assert results[0] = result;
        %{
            target_result = hex(ids.result.high * 2 ** 128 + ids.result.low)
            print(f"Task Result: {target_result}")
        %}

        let task_hash = compute_tasks_hash_v2{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(program_hash=program_hash, inputs=module_task.module_inputs, inputs_len= module_task.module_inputs_len);

        // %{ print("Task;", hex(ids.task_hash.high * 2 ** 128 + ids.task_hash.low)) %}

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
