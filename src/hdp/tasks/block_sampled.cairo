from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bitwise import bitwise_xor
from src.libs.utils import word_reverse_endian_64, word_reverse_endian_16_RC
from src.hdp.types import BlockSampledDataLake, BlockSampledComputationalTask, AccountState
from src.hdp.compiler.block_sampled import init_block_sampled, fetch_data_points
from src.hdp.tasks.sum import compute_sum
from src.hdp.tasks.avg import compute_avg

namespace BlockSampledTask {
    func init{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        keccak_ptr: KeccakBuiltin*,
        block_sampled_tasks: BlockSampledComputationalTask*
    }(tasks_input: felt**, tasks_bytes_len: felt*, datalakes_input: felt**, datalakes_bytes_len: felt*, n_tasks: felt, index: felt) {
        alloc_locals;

        if (index == n_tasks) {
            return ();
        } else {

            local property_type;
            %{
                ids.property_type = block_sampled_tasks[ids.index]["property_type"]
            %}

            let datalake = init_block_sampled(datalakes_input[index], datalakes_bytes_len[index], property_type);
           
            let (data_lake_hash_low, data_lake_hash_high, aggregate_fn_id) = extract_params{
                range_check_ptr=range_check_ptr,
            }(input=tasks_input[index]);

            // ensure task contains correct data lake hash
            assert data_lake_hash_low = datalake.hash.low;
            assert data_lake_hash_high = datalake.hash.high;

            let (hash) = keccak(tasks_input[index], tasks_bytes_len[index]);

            assert block_sampled_tasks[index] = BlockSampledComputationalTask(
                aggregate_fn_id=aggregate_fn_id,
                hash=hash,
                datalake=datalake,
            );

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

    // Executes the aggregate_fn of the passed task
    func execute{
        range_check_ptr,
        poseidon_ptr: PoseidonBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        account_dict: DictAccess*,
        account_states: AccountState*,
        pow2_array: felt*,
        tasks: BlockSampledComputationalTask*,
    }(results: Uint256*, tasks_len: felt, index: felt) {
        alloc_locals;

        if(index == tasks_len) {
            return ();
        }

        let (data_points, data_points_len) = fetch_data_points(tasks[index]);

        if (tasks[index].aggregate_fn_id == 0){
            let result = compute_avg{
                range_check_ptr=range_check_ptr,    
            }(values=data_points, values_len=data_points_len);

            %{
                print(f"Computing Average")
                print(f"result: {ids.result.low} {ids.result.high}")
            %}

            assert [results] = result;

            return execute(
                results=results + Uint256.SIZE,
                tasks_len=tasks_len,
                index=index + 1,
            );
        }

        if (tasks[index].aggregate_fn_id == 1){
            let result = compute_sum{
                range_check_ptr=range_check_ptr,    
            }(values=data_points, values_len=data_points_len);

            %{
                print(f"Computing Sum")
                print(f"result: {ids.result.low} {ids.result.high}")
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
func extract_params{
    range_check_ptr,
}(input: felt*) -> (data_lake_hash_low: felt, data_lake_hash_high: felt, aggregate_fn_id: felt) {
    alloc_locals;
    // HeaderProp Input Layout:
    // 0-3: data_lake_hash
    // 4-7: aggregate_fn_id (chunk 4: value, chunk 5-7: padding)
    // 8-: aggregate_fn_ctx -> Unimplemented!
    
    // Copy data_lake_hash
    let data_lake_hash_low = [input] + [input + 1] * 0x10000000000000000;
    let data_lake_hash_high = [input + 2] + [input + 3] * 0x10000000000000000;
   
    // ensure aggregate_fn_id is not overflowing
    assert [ input + 5] = 0;

    let task = [input + 4];

    //"avg".encode(uft-8).to_le()
    if(task == 0x677661) {
        return (data_lake_hash_low=data_lake_hash_low, data_lake_hash_high=data_lake_hash_high, aggregate_fn_id=0);
    }

    //"sum".encode(uft-8).to_le()
    if(task == 0x6D7573) {
        return (data_lake_hash_low=data_lake_hash_low, data_lake_hash_high=data_lake_hash_high, aggregate_fn_id=1);
    }
    
    //"min".encode(uft-8).to_le()
    if(task == 0x6E696D) { 
        return (data_lake_hash_low=data_lake_hash_low, data_lake_hash_high=data_lake_hash_high, aggregate_fn_id=2);
    }
    
    //"max".encode(uft-8).to_le()
    if(task == 0x78616D) {
        return (data_lake_hash_low=data_lake_hash_low, data_lake_hash_high=data_lake_hash_high, aggregate_fn_id=3);
    }

    // Terminate on invalid aggregate_fn_id
    assert 0 = 1;

    return (data_lake_hash_low=data_lake_hash_low, data_lake_hash_high=data_lake_hash_high, aggregate_fn_id=3);
}