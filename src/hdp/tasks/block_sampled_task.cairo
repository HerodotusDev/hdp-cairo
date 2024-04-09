from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc

from src.hdp.types import BlockSampledDataLake, BlockSampledComputationalTask, AccountValues, Header
from src.hdp.datalakes.block_sampled_datalake import init_block_sampled, fetch_data_points
from src.hdp.tasks.aggregate_functions.sum import compute_sum
from src.hdp.tasks.aggregate_functions.avg import compute_avg
from src.hdp.tasks.aggregate_functions.min_max import uint256_min_le, uint256_max_le
from src.hdp.tasks.aggregate_functions.count_if import count_if
from src.libs.rlp_little import extract_byte_at_pos

namespace AGGREGATE_FN {
    const AVG = 0;
    const SUM = 1;
    const MIN = 2;
    const MAX = 3;
    const COUNT = 4;
    const MERKLE = 5;
}



namespace BlockSampledTask {
    func init{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        keccak_ptr: KeccakBuiltin*,
        block_sampled_tasks: BlockSampledComputationalTask*,
        pow2_array: felt*,
    }(tasks_input: felt**, tasks_bytes_len: felt*, datalakes_input: felt**, datalakes_bytes_len: felt*, n_tasks: felt, index: felt) {
        alloc_locals;

        if (index == n_tasks) {
            return ();
        } else {

            local property_type;
            %{
                # ToDo: This is bad design
                ids.property_type = block_sampled_tasks[ids.index]["property_type"]
            %}

            let datalake = init_block_sampled(datalakes_input[index], datalakes_bytes_len[index], property_type);
           
            let (local task) = extract_params_and_construct_task{
                range_check_ptr=range_check_ptr,
                bitwise_ptr=bitwise_ptr,
                keccak_ptr=keccak_ptr,
            }(input=tasks_input[index], input_bytes_len=tasks_bytes_len[index], datalake=datalake);

            assert block_sampled_tasks[index] = task;

            return init(
                tasks_input=tasks_input,
                tasks_bytes_len=tasks_bytes_len,
                datalakes_input=datalakes_input,
                datalakes_bytes_len=datalakes_bytes_len,
                n_tasks=n_tasks,
                index=index + 1,
            );
        }
    }

    // Executes the aggregate_fn of the passed tasks
    func execute{
        range_check_ptr,
        poseidon_ptr: PoseidonBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        account_dict: DictAccess*,
        account_values: AccountValues*,
        storage_dict: DictAccess*,
        storage_values: Uint256*,
        header_dict: DictAccess*,
        headers: Header*,
        pow2_array: felt*,
        tasks: BlockSampledComputationalTask*,
    }(results: Uint256*, tasks_len: felt, index: felt) {
        alloc_locals;

        if(index == tasks_len) {
            return ();
        }

        let (data_points, data_points_len) = fetch_data_points(tasks[index]);

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.AVG){
            let result = compute_avg(values=data_points, values_len=data_points_len);
            assert [results] = result;

            return execute(
                results=results + Uint256.SIZE,
                tasks_len=tasks_len,
                index=index + 1,
            );
        }

        if(tasks[index].aggregate_fn_id == AGGREGATE_FN.SUM){
            let result = compute_sum(values_le=data_points, values_len=data_points_len);
            assert [results] = result;

            return execute(
                results=results + Uint256.SIZE,
                tasks_len=tasks_len,
                index=index + 1,
            );
        }

        if(tasks[index].aggregate_fn_id == AGGREGATE_FN.MIN){
            let result = uint256_min_le(data_points, data_points_len);
            assert [results] = result;

            return execute(
                results=results + Uint256.SIZE,
                tasks_len=tasks_len,
                index=index + 1,
            );
        }

        if(tasks[index].aggregate_fn_id == AGGREGATE_FN.MAX){
            let result = uint256_max_le(data_points, data_points_len);
            assert [results] = result;

            return execute(
                results=results + Uint256.SIZE,
                tasks_len=tasks_len,
                index=index + 1,
            );
        }

        if(tasks[index].aggregate_fn_id == AGGREGATE_FN.COUNT){
            let (res_felt) = count_if(data_points, data_points_len, tasks[index].ctx_operator, tasks[index].ctx_value);
            let result = felt_to_uint256(res_felt);

            %{
                print("Count: ", ids.res_felt)
            %}
            assert [results] = result;

            return execute(
                results=results + Uint256.SIZE,
                tasks_len=tasks_len,
                index=index + 1,
            );
        }

        // Unknonwn aggregate_fn_id
        assert 0 = 1;

        return ();

    }
}


// Internal Functions:
func extract_params_and_construct_task{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    pow2_array: felt*
}(input: felt*, input_bytes_len: felt, datalake: BlockSampledDataLake) -> (task: BlockSampledComputationalTask) {
    alloc_locals;
    // HeaderProp Input Layout:
    // 0-3: data_lake_hash
    // 4-7: aggregate_fn_id (chunk 7: value, chunks 4-6: padding)
    // 8-11: ctx_operator (chunk 11: value, chunks 7-10: padding)
    // 12-15: ctx_value
    
    // Copy data_lake_hash
    let datalake_hash_low = [input] + [input + 1] * 0x10000000000000000;
    let datalake_hash_high = [input + 2] + [input + 3] * 0x10000000000000000;

    // ensure task contains correct data lake hash
    assert datalake_hash_low = datalake.hash.low;
    assert datalake_hash_high = datalake.hash.high;

    let (hash) = keccak(input, input_bytes_len);
   
    let task_word = [input + 7];
    let task = extract_byte_at_pos(task_word, 7, pow2_array);
    // ensure aggregate_fn_id is not overflowing
    assert [ input + 6] = 0;

    if (task == AGGREGATE_FN.COUNT) {
        let operator_word = [input + 11];
        let ctx_operator = extract_byte_at_pos(operator_word, 7, pow2_array);

        let ctx_value_le = Uint256(
            low=[input + 12] + [input + 13] * 0x10000000000000000, 
            high=[input + 14] + [input + 15] * 0x10000000000000000
        );
        let (ctx_value) = uint256_reverse_endian(ctx_value_le);

        return (task=BlockSampledComputationalTask(
            hash=hash,
            datalake=datalake,
            aggregate_fn_id=AGGREGATE_FN.COUNT,
            ctx_operator=ctx_operator,
            ctx_value=ctx_value,
        ));
    
    } else {
        return (task=BlockSampledComputationalTask(
            hash=hash,
            datalake=datalake,
            aggregate_fn_id=task,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        ));
    }
}