%builtins output range_check bitwise keccak poseidon

from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend

from src.hdp.types import (
    Header,
    HeaderProof,
    MMRMeta,
    Account,
    AccountValues,
    StorageItem,
    BlockSampledDataLake,
    BlockSampledComputationalTask,
)
from src.hdp.mmr import verify_mmr_meta
from src.hdp.header import verify_headers_inclusion
from src.hdp.account import populate_account_segments, verify_n_accounts
from src.hdp.storage_item import populate_storage_item_segments, verify_n_storage_items
from src.hdp.memorizer import HeaderMemorizer, AccountMemorizer, StorageMemorizer, MEMORIZER_DEFAULT
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys

from src.hdp.tasks.block_sampled import BlockSampledTask
from src.hdp.merkle import compute_tasks_root, compute_results_root
from src.hdp.utils import compute_results_entry

func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    run{
        output_ptr=output_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
    }();

    return ();
}

func run{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local expected_results_root: Uint256;
    local expected_tasks_root: Uint256;

    // Header Params
    local headers_len: felt;
    let (headers: Header*) = alloc();

    // MMR Params
    local mmr_meta: MMRMeta;

    // Account Params
    let (accounts: Account*) = alloc();
    let (account_values: AccountValues*) = alloc();
    local accounts_len: felt;

    // Storage Params
    let (storage_items: StorageItem*) = alloc();
    let (storage_values: Uint256*) = alloc();
    local storage_items_len: felt;

    // Memorizers
    let (header_dict, header_dict_start) = HeaderMemorizer.initialize();
    let (account_dict, account_dict_start) = AccountMemorizer.initialize();
    let (storage_dict, storage_dict_start) = StorageMemorizer.initialize();

    // Task and Datalake
    local block_sampled_tasks_len: felt;
    let (block_sampled_tasks_input: felt**) = alloc();
    let (block_sampled_tasks_bytes_len) = alloc();

    let (block_sampled_data_lakes_input: felt**) = alloc();
    let (block_sampled_data_lakes_bytes_len) = alloc();
    let (block_sampled_tasks: BlockSampledComputationalTask*) = alloc();

    let (results: Uint256*) = alloc();

    // Misc
    let pow2_array: felt* = pow2alloc128();

    %{
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

        def write_headers(ptr, headers):
            offset = 0
            ids.headers_len = len(headers)

            for header in headers:
                memory[ptr._reference_value + offset] = segments.gen_arg(hex_to_int_array(header["rlp"]))
                memory[ptr._reference_value + offset + 1] = len(header["rlp"])
                memory[ptr._reference_value + offset + 2] = header["rlp_bytes_len"]
                memory[ptr._reference_value + offset + 3] = header["proof"]["leaf_idx"]
                memory[ptr._reference_value + offset + 4] = len(header["proof"]["mmr_path"])
                memory[ptr._reference_value + offset + 5] = segments.gen_arg(hex_to_int_array(header["proof"]["mmr_path"]))
                offset += 6
    %}
    // if these hints are one hint, the compiler goes on strike.
    %{
        def write_mmr_meta(mmr_meta):
            ids.mmr_meta.id = mmr_meta["id"]
            ids.mmr_meta.root = hex_to_int(mmr_meta["root"])
            ids.mmr_meta.size = mmr_meta["size"]
            ids.mmr_meta.peaks_len = len(mmr_meta["peaks"])
            ids.mmr_meta.peaks = segments.gen_arg(hex_to_int_array(mmr_meta["peaks"]))

        ids.expected_results_root.low = hex_to_int(program_input["results_root"]["low"])
        ids.expected_results_root.high = hex_to_int(program_input["results_root"]["high"])
        ids.expected_tasks_root.low = hex_to_int(program_input["tasks_root"]["low"])
        ids.expected_tasks_root.high = hex_to_int(program_input["tasks_root"]["high"])

        # MMR Meta
        write_mmr_meta(program_input['mmr'])

        # Header Params
        ids.headers_len = len(program_input["headers"])
        write_headers(ids.headers, program_input["headers"])

        # Account + Storage Params
        ids.accounts_len = len(program_input['accounts'])
        ids.storage_items_len = len(program_input['storages'])

        # Task and Datalake
        tasks_input, data_lakes_input, tasks_bytes_len, data_lake_bytes_len = ([], [], [], [])
        block_sampled_tasks = filtered_tasks = [task for task in program_input['tasks'] if task["datalake_type"] == 0]

        for task in block_sampled_tasks:
            tasks_input.append(hex_to_int_array(task["encoded_task"]))
            tasks_bytes_len.append(task["task_bytes_len"])
            data_lakes_input.append(hex_to_int_array(task["encoded_datalake"]))
            data_lake_bytes_len.append(task["datalake_bytes_len"])

        segments.write_arg(ids.block_sampled_tasks_input, tasks_input)
        segments.write_arg(ids.block_sampled_tasks_bytes_len, tasks_bytes_len)
        segments.write_arg(ids.block_sampled_data_lakes_input, data_lakes_input)
        segments.write_arg(ids.block_sampled_data_lakes_bytes_len, data_lake_bytes_len)

        ids.block_sampled_tasks_len = len(block_sampled_tasks)
    %}

    // Check 1: Ensure we have a valid pair of mmr_root and peaks
    verify_mmr_meta{pow2_array=pow2_array}(mmr_meta);

    // Write the peaks to the dict if valid
    let (local peaks_dict) = default_dict_new(default_value=0);
    tempvar peaks_dict_start = peaks_dict;
    write_felt_array_to_dict_keys{dict_end=peaks_dict}(
        array=mmr_meta.peaks, index=mmr_meta.peaks_len - 1
    );

    // Check 2: Ensure the header is contained in a peak, and that the peak is known
    verify_headers_inclusion{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        pow2_array=pow2_array,
        peaks_dict=peaks_dict,
        header_dict=header_dict,
    }(headers=headers, mmr_size=mmr_meta.size, n_headers=headers_len, index=0);

    populate_account_segments(accounts=accounts, n_accounts=accounts_len, index=0);

    populate_storage_item_segments(
        storage_items=storage_items, n_storage_items=storage_items_len, index=0
    );

    // Check 3: Ensure the account proofs are valid
    verify_n_accounts{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        headers=headers,
        header_dict=header_dict,
        account_dict=account_dict,
        pow2_array=pow2_array,
    }(
        accounts=accounts,
        accounts_len=accounts_len,
        account_values=account_values,
        account_value_idx=0,
    );

    // Check 4: Ensure the account slot proofs are valid
    verify_n_storage_items{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        account_values=account_values,
        account_dict=account_dict,
        storage_dict=storage_dict,
        pow2_array=pow2_array,
    }(
        storage_items=storage_items,
        storage_items_len=storage_items_len,
        storage_values=storage_values,
        state_idx=0,
    );

    // Verified data is now in memorizer, and can be used for further computation
    BlockSampledTask.init{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        block_sampled_tasks=block_sampled_tasks,
    }(
        block_sampled_tasks_input,
        block_sampled_tasks_bytes_len,
        block_sampled_data_lakes_input,
        block_sampled_data_lakes_bytes_len,
        block_sampled_tasks_len,
        0,
    );

    BlockSampledTask.execute{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        bitwise_ptr=bitwise_ptr,
        account_dict=account_dict,
        account_values=account_values,
        storage_dict=storage_dict,
        storage_values=storage_values,
        header_dict=header_dict,
        headers=headers,
        pow2_array=pow2_array,
        tasks=block_sampled_tasks,
    }(results=results, tasks_len=block_sampled_tasks_len, index=0);

    let tasks_root = compute_tasks_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(tasks=block_sampled_tasks, tasks_len=block_sampled_tasks_len);

    let results_root = compute_results_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(tasks=block_sampled_tasks, results=results, tasks_len=block_sampled_tasks_len);

    %{
        print(f"Tasks Root: {hex(ids.tasks_root.low)} {hex(ids.tasks_root.high)}")
        print(f"Results Root: {hex(ids.results_root.low)} {hex(ids.results_root.high)}")
    %}

    // Post Verification Checks: Ensure the roots match the expected roots
    assert expected_tasks_root.low = tasks_root.low;
    assert expected_tasks_root.high = tasks_root.high;
    assert expected_results_root.low = results_root.low;
    assert expected_results_root.high = results_root.high;

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(peaks_dict_start, peaks_dict, 0);
    default_dict_finalize(header_dict_start, header_dict, MEMORIZER_DEFAULT);
    default_dict_finalize(account_dict_start, account_dict, MEMORIZER_DEFAULT);
    default_dict_finalize(storage_dict_start, storage_dict, MEMORIZER_DEFAULT);

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
