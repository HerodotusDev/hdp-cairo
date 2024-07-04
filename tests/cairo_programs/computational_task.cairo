from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.registers import get_fp_and_pc

from tests.cairo_programs.block_sampled_datalake import block_sampled_datalake_eq
from tests.cairo_programs.test_vectors import BlockSampledTaskMocker

from src.tasks.computational import Task, extract_params_and_construct_task, AGGREGATE_FN
from src.decoders.header_decoder import HeaderField
from src.datalakes.datalake import DatalakeType
from src.datalakes.block_sampled_datalake import BlockSampledProperty
from src.types import BlockSampledDataLake, ComputationalTask, ChainInfo
from packages.eth_essentials.lib.utils import pow2alloc128
from src.chain_info import fetch_chain_info

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    alloc_locals;

    let pow2_array: felt* = pow2alloc128();
    let (local chain_info) = fetch_chain_info(0x01);

    test_computational_task_init{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        chain_info=chain_info,
        pow2_array=pow2_array,
    }();

    test_computational_task_param_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        chain_info=chain_info,
        pow2_array=pow2_array,
    }();

    return ();
}

func test_computational_task_init{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let (tasks: ComputationalTask*) = alloc();

    local tasks_len: felt;

    %{
        def hex_to_int(x):
            return int(x, 16)

        def hex_to_int_array(hex_array):
            return [int(x, 16) for x in hex_array]

        program_input["tasks"] = [{
            "type": "datalake_compute",
            "context": {
                "task_bytes_len": 128,
                "encoded_task": ["0x25ca8521ba63d557", "0xc9f9f40f48f31e27", "0x739b20c59ba605a5", "0x813cc91cdc15ae0e", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0"],
                "datalake_bytes_len": 224,
                "encoded_datalake": ["0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0x0", "0xf826540000000000", "0x0", "0x0", "0x0", "0x1527540000000000", "0x0", "0x0", "0x0", "0x100000000000000", "0x0", "0x0", "0x0", "0xa000000000000000", "0x0", "0x0", "0x0", "0x200000000000000", "0x1101", "0x0", "0x0", "0x0"],
                "datalake_type": 0,
                "property_type": 1
            }
        }]

        ids.tasks_len = len(program_input["tasks"])
    %}

    let (properties) = alloc();
    %{ segments.write_arg(ids.properties, [ids.HeaderField.BLOB_GAS_USED]) %}

    local expected_datalake: BlockSampledDataLake;

    assert expected_datalake = BlockSampledDataLake(
        block_range_start=5515000,
        block_range_end=5515029,
        increment=1,
        property_type=BlockSampledProperty.HEADER,
        properties=properties,
    );

    let datalake_ptr: felt* = cast(&expected_datalake, felt*);

    local expected_task: ComputationalTask;

    assert expected_task = ComputationalTask(
        chain_id=0x1,
        hash=Uint256(0xB85414EBA86F94BAC1CA653D3D3CF014, 0x212F54CE9F4342F21C5D865F1641AABC),
        datalake_ptr=datalake_ptr,
        datalake_type=DatalakeType.BLOCK_SAMPLED,
        aggregate_fn_id=AGGREGATE_FN.AVG,
        ctx_operator=0,
        ctx_value=Uint256(low=0, high=0),
    );

    Task.init{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr, tasks=tasks
    }(tasks_len, 0);

    let task = tasks[0];
    assert task.hash.low = expected_task.hash.low;
    assert task.hash.high = expected_task.hash.high;
    assert task.datalake_type = expected_task.datalake_type;
    assert task.aggregate_fn_id = expected_task.aggregate_fn_id;
    assert task.ctx_operator = expected_task.ctx_operator;
    assert task.ctx_value.low = expected_task.ctx_value.low;
    assert task.ctx_value.high = expected_task.ctx_value.high;

    let datalake: BlockSampledDataLake = [cast(task.datalake_ptr, BlockSampledDataLake*)];
    block_sampled_datalake_eq(datalake, expected_datalake, datalake.property_type);

    assert task.aggregate_fn_id = expected_task.aggregate_fn_id;

    return ();
}

func test_computational_task_param_decoding{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    local chain_id = 0x1;

    // AVG:
    let (
        exp_avg_task, avg_input, avg_bytes_len, avg_datalake, hash
    ) = BlockSampledTaskMocker.get_avg_task();

    let (avg_task) = extract_params_and_construct_task(
        chain_id,
        avg_input,
        avg_bytes_len,
        hash,
        exp_avg_task.datalake_ptr,
        exp_avg_task.datalake_type,
    );
    task_eq(avg_task, exp_avg_task);

    // SUM:
    let (
        exp_sum_task, sum_input, sum_bytes_len, sum_datalake, hash
    ) = BlockSampledTaskMocker.get_sum_task();
    let (sum_task) = extract_params_and_construct_task(
        chain_id,
        sum_input,
        sum_bytes_len,
        hash,
        exp_sum_task.datalake_ptr,
        exp_sum_task.datalake_type,
    );
    task_eq(sum_task, exp_sum_task);

    // MIN:
    let (
        exp_min_task, min_input, min_bytes_len, min_datalake, hash
    ) = BlockSampledTaskMocker.get_min_task();
    let (min_task) = extract_params_and_construct_task(
        chain_id,
        min_input,
        min_bytes_len,
        hash,
        exp_min_task.datalake_ptr,
        exp_min_task.datalake_type,
    );
    task_eq(min_task, exp_min_task);

    // MAX:
    let (
        exp_max_task, max_input, max_bytes_len, max_datalake, hash
    ) = BlockSampledTaskMocker.get_max_task();
    let (max_task) = extract_params_and_construct_task(
        chain_id,
        max_input,
        max_bytes_len,
        hash,
        exp_max_task.datalake_ptr,
        exp_max_task.datalake_type,
    );
    task_eq(max_task, exp_max_task);

    // COUNT_IF:
    let (
        exp_count_if_task, count_if_input, count_if_bytes_len, _, hash
    ) = BlockSampledTaskMocker.get_count_if_task();
    let (count_if_task) = extract_params_and_construct_task(
        chain_id,
        count_if_input,
        count_if_bytes_len,
        hash,
        exp_count_if_task.datalake_ptr,
        exp_count_if_task.datalake_type,
    );
    task_eq(count_if_task, exp_count_if_task);

    return ();
}

func task_eq(a: ComputationalTask, b: ComputationalTask) {
    assert a.chain_id = b.chain_id;
    assert a.hash.low = b.hash.low;
    assert a.hash.high = b.hash.high;
    assert a.aggregate_fn_id = b.aggregate_fn_id;
    assert a.ctx_operator = b.ctx_operator;
    assert a.ctx_value.high = b.ctx_value.high;
    assert a.ctx_value.low = b.ctx_value.low;

    return ();
}
