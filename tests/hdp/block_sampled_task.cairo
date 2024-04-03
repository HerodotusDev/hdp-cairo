from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin

from tests.hdp.block_sampled_datalake import block_sampled_datalake_eq
from tests.hdp.test_vectors import BlockSampledTaskMocker

from src.hdp.tasks.block_sampled_task import BlockSampledTask, extract_params
from src.hdp.types import BlockSampledDataLake, BlockSampledComputationalTask
from src.hdp.merkle import compute_tasks_root

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    test_block_sampled_task_init{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }();

    test_block_sampled_task_param_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }();

    return ();
}

func test_block_sampled_task_init{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (
        expected_tasks,
        tasks_input,
        tasks_bytes_len,
        datalakes_inputs,
        datalakes_bytes_len,
        tasks_len,
    ) = BlockSampledTaskMocker.get_account_task();

    let (tasks: BlockSampledComputationalTask*) = alloc();

    BlockSampledTask.init{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        block_sampled_tasks=tasks,
    }(tasks_input, tasks_bytes_len, datalakes_inputs, datalakes_bytes_len, tasks_len, 0);

    let task = tasks[0];
    let expected_task = expected_tasks[0];

    assert task.hash.low = expected_task.hash.low;
    assert task.hash.high = expected_task.hash.high;
    block_sampled_datalake_eq(task.datalake, expected_task.datalake, task.datalake.property_type);

    assert task.aggregate_fn_id = expected_task.aggregate_fn_id;

    return ();
}

func test_block_sampled_task_param_decoding{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    // AVG:
    let (
        avg_input, avg_expected_hash_low, avg_expected_hash_high, avg_expected_aggregate_fn_id
    ) = BlockSampledTaskMocker.get_avg_params();
    let (avg_hash_low, avg_hash_high, avg_aggregate_fn_id) = extract_params(avg_input);

    assert avg_hash_low = avg_expected_hash_low;
    assert avg_hash_high = avg_expected_hash_high;
    assert avg_aggregate_fn_id = avg_expected_aggregate_fn_id;

    // SUM:
    let (
        sum_input, sum_expected_hash_low, sum_expected_hash_high, sum_expected_aggregate_fn_id
    ) = BlockSampledTaskMocker.get_sum_params();
    let (sum_hash_low, sum_hash_high, sum_aggregate_fn_id) = extract_params(sum_input);

    assert sum_hash_low = sum_expected_hash_low;
    assert sum_hash_high = sum_expected_hash_high;
    assert sum_aggregate_fn_id = sum_expected_aggregate_fn_id;

    // MIN:
    let (
        min_input, min_expected_hash_low, min_expected_hash_high, min_expected_aggregate_fn_id
    ) = BlockSampledTaskMocker.get_min_params();
    let (min_hash_low, min_hash_high, min_aggregate_fn_id) = extract_params(min_input);

    assert min_hash_low = min_expected_hash_low;
    assert min_hash_high = min_expected_hash_high;
    assert min_aggregate_fn_id = min_expected_aggregate_fn_id;

    // MAX:
    let (
        max_input, max_expected_hash_low, max_expected_hash_high, max_expected_aggregate_fn_id
    ) = BlockSampledTaskMocker.get_max_params();

    let (max_hash_low, max_hash_high, max_aggregate_fn_id) = extract_params(max_input);

    assert max_hash_low = max_expected_hash_low;
    assert max_hash_high = max_expected_hash_high;
    assert max_aggregate_fn_id = max_expected_aggregate_fn_id;

    return ();
}
