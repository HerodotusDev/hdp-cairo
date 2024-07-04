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

from src.types import MMRMeta, ComputationalTask, ChainInfo

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
    local mmr_meta: MMRMeta;

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

        def write_mmr_meta(mmr_meta):
            ids.mmr_meta.id = mmr_meta["id"]
            ids.mmr_meta.root = hex_to_int(mmr_meta["root"])
            ids.mmr_meta.size = mmr_meta["size"]
            ids.mmr_meta.peaks_len = len(mmr_meta["peaks"])
            ids.mmr_meta.peaks = segments.gen_arg(hex_to_int_array(mmr_meta["peaks"]))
            # ids.chain_id = mmr_meta["chain_id"]

        # MMR Meta
        write_mmr_meta(program_input["proofs"]['mmr_meta'])

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
        mmr_meta=mmr_meta,
        chain_info=chain_info,
    }();

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
        if "result_root" in program_input:
            assert ids.results_root.high * 2 ** 128 + ids.results_root.low  == hex_to_int(program_input["result_root"]), "Expected results root mismatch"

        if "task_root" in program_input:
            assert ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low  == hex_to_int(program_input["task_root"]), "Expected results root mismatch"
    %}

    %{
        import json

        dictionary = dict()

        dictionary["task_root"] = hex(ids.tasks_root.high * 2 ** 128 + ids.tasks_root.low )
        dictionary["results_root"] = hex(ids.results_root.high * 2 ** 128 + ids.results_root.low)
        dict_results = list()
        dictionary["results"] = list()

        print(f"Results len: {ids.results_len}")
        for i in range(ids.results_len):
            dict_results.append(memory[ids.results + i])


        for result in dict_results:
            dictionary["results"].append({
                "low": hex(result.low),
                "high": hex(result.high)
            })

        with open(cairo_run_output_path, 'w') as json_file:
            json.dump(list, json_file)
    %}

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(peaks_dict_start, peaks_dict, 0);
    default_dict_finalize(header_dict_start, header_dict, 7);
    default_dict_finalize(account_dict_start, account_dict, 7);
    default_dict_finalize(storage_dict_start, storage_dict, 7);
    default_dict_finalize(block_tx_dict_start, block_tx_dict, 7);
    default_dict_finalize(block_receipt_dict_start, block_receipt_dict, 7);

    [ap] = mmr_meta.root;
    [ap] = [output_ptr], ap++;

    [ap] = mmr_meta.size;
    [ap] = [output_ptr + 1], ap++;

    [ap] = results_root.low;
    [ap] = [output_ptr + 2], ap++;

    [ap] = results_root.high;
    [ap] = [output_ptr + 3], ap++;

    [ap] = tasks_root.low;
    [ap] = [output_ptr + 4], ap++;

    [ap] = tasks_root.high;
    [ap] = [output_ptr + 5], ap++;

    [ap] = output_ptr + 6, ap++;
    let output_ptr = output_ptr + 6;
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
        local inputs_len: felt;
        let (inputs) = alloc();

        %{
            from tools.py.schema import CompiledClass

            task = program_input["tasks"][0]["context"]
            compiled_class = CompiledClass.Schema().load(task["module_class"])

            ids.inputs_len = len(task["inputs"])
            segments.write_arg(ids.inputs, hex_to_int_array(task["inputs"]))
        %}

        let (result, program_hash) = compute_contract(inputs, inputs_len);
        assert results[0] = result;

        %{ print("Result:", ids.result.high * 2 ** 128 + ids.result.low) %}

        let task_hash = compute_tasks_hash_v2{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(program_hash=program_hash, inputs=inputs, inputs_len=inputs_len);

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
