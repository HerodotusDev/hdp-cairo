from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin

from tests.hdp.block_sampled_datalake import block_sampled_datalake_eq
from tests.hdp.test_vectors import BlockSampledTaskMocker

from src.hdp.tasks.block_sampled_task import BlockSampledTask, extract_params_and_construct_task
from src.hdp.types import BlockSampledDataLake, BlockSampledComputationalTask
from src.hdp.merkle import compute_tasks_root
from src.libs.utils import pow2alloc128

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    let pow2_array: felt* = pow2alloc128();

    test_block_sampled_task_init{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        pow2_array=pow2_array,
    }();

    test_block_sampled_task_param_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        pow2_array=pow2_array,
    }();

    return ();
}

func test_block_sampled_task_init{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}() {
    alloc_locals;

    let (
        expected_task,
        tasks_input,
        tasks_bytes_len,
        expected_datalake,
        datalakes_inputs,
        datalakes_bytes_len,
        tasks_len,
    ) = BlockSampledTaskMocker.get_init_data();

    let (tasks: BlockSampledComputationalTask*) = alloc();

    BlockSampledTask.init{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        block_sampled_tasks=tasks,
    }(tasks_input, tasks_bytes_len, datalakes_inputs, datalakes_bytes_len, tasks_len, 0);

    let task = tasks[0];

    assert task.hash.low = expected_task.hash.low;
    assert task.hash.high = expected_task.hash.high;
    block_sampled_datalake_eq(task.datalake, expected_task.datalake, task.datalake.property_type);

    assert task.aggregate_fn_id = expected_task.aggregate_fn_id;

    return ();
}

func test_block_sampled_task_param_decoding{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}() {
    alloc_locals;

    // AVG:
    let (
        expected_avg_task, avg_input, avg_bytes_len, avg_datalake
    ) = BlockSampledTaskMocker.get_avg_task();
    let (avg_task) = extract_params_and_construct_task(avg_input, avg_bytes_len, avg_datalake);
    task_eq(avg_task, expected_avg_task);

    // SUM:
    let (
        expected_sum_task, sum_input, sum_bytes_len, sum_datalake
    ) = BlockSampledTaskMocker.get_sum_task();
    let (sum_task) = extract_params_and_construct_task(sum_input, sum_bytes_len, sum_datalake);
    task_eq(sum_task, expected_sum_task);

    // MIN:
    let (
        expected_min_task, min_input, min_bytes_len, min_datalake
    ) = BlockSampledTaskMocker.get_min_task();
    let (min_task) = extract_params_and_construct_task(min_input, min_bytes_len, min_datalake);
    task_eq(min_task, expected_min_task);

    // MAX:
    let (
        expected_max_task, max_input, max_bytes_len, max_datalake
    ) = BlockSampledTaskMocker.get_max_task();
    let (max_task) = extract_params_and_construct_task(max_input, max_bytes_len, max_datalake);
    task_eq(max_task, expected_max_task);

    // COUNT_IF:
    let (
        expected_count_if_task, count_if_input, count_if_bytes_len, count_if_datalake
    ) = BlockSampledTaskMocker.get_count_if_task();
    let (count_if_task) = extract_params_and_construct_task(
        count_if_input, count_if_bytes_len, count_if_datalake
    );
    task_eq(count_if_task, expected_count_if_task);

    return ();
}

func task_eq(a: BlockSampledComputationalTask, b: BlockSampledComputationalTask) {
    assert a.hash.low = b.hash.low;
    assert a.hash.high = b.hash.high;
    assert a.aggregate_fn_id = b.aggregate_fn_id;
    assert a.ctx_operator = b.ctx_operator;
    assert a.ctx_value.high = b.ctx_value.high;
    assert a.ctx_value.low = b.ctx_value.low;

    return ();
}
