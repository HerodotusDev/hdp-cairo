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
from src.merkle import compute_tasks_root, compute_results_root
from src.chain_info import fetch_chain_info

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
        write_mmr_meta(program_input['mmr'])

        # Task and Datalake
        ids.tasks_len = len(program_input['tasks'])

        ids.chain_id = 1
        if "hdp_version" in program_input:
            ids.hdp_version = hex_to_int(program_input["hdp_version"])
        else:
            ids.hdp_version = 1
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

    
    let (local results) = compute_tasks{
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
    }(hdp_version=hdp_version, tasks_len=tasks_len, index=0);

    let tasks_root = compute_tasks_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(tasks=tasks, tasks_len=tasks_len);

    let results_root = compute_results_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(tasks=tasks, results=results, tasks_len=tasks_len);

    %{
        print(f"Tasks Root: {hex(ids.tasks_root.low)} {hex(ids.tasks_root.high)}")
        print(f"Results Root: {hex(ids.results_root.low)} {hex(ids.results_root.high)}")
    %}

    // Post Verification Checks: Ensure the roots match the expected roots
    %{
        if "results_root" in program_input:
            assert ids.results_root.low == hex_to_int(program_input["results_root"]["low"]), "Expected results root mismatch"
            assert ids.results_root.high == hex_to_int(program_input["results_root"]["high"]), "Expected results root mismatch"

        if "tasks_root" in program_input:
            assert ids.tasks_root.low == hex_to_int(program_input["tasks_root"]["low"]), "Expected tasks root mismatch"
            assert ids.tasks_root.high == hex_to_int(program_input["tasks_root"]["high"]), "Expected tasks root mismatch"
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
} (hdp_version: felt, tasks_len: felt, index: felt) -> (results: Uint256*) {
    alloc_locals;

    let (results: Uint256*) = alloc();

    if (hdp_version == 1) {
        Task.init{
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr,
            keccak_ptr=keccak_ptr,
            tasks=tasks,
            chain_info=chain_info,
            pow2_array=pow2_array,
        }(tasks_len, 0);

        Task.execute(results=results, tasks_len=tasks_len, index=0);

        return (results=results);
    }

    if (hdp_version == 2) {
        assert 1 = 1;
        return (results=results);
    }

    assert 1 = 0;
    return (results=results);
}