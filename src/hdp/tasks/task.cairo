from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bitwise import bitwise_xor
from src.libs.utils import word_reverse_endian_64, word_reverse_endian_16_RC
from src.hdp.types import BlockSampledDataLake, ComputationalTask

func init_with_block_sampled{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(task_input: felt*, task_input_bytes_len: felt, block_sampled: BlockSampledDataLake) -> ComputationalTask {
    alloc_locals;
    let (data_lake_hash_low, data_lake_hash_high, aggregate_fn_id) = extract_params{
        range_check_ptr=range_check_ptr,
    }(input=task_input);

    // ensure task contains correct data lake hash
    assert data_lake_hash_low = block_sampled.hash.low;
    assert data_lake_hash_high = block_sampled.hash.high;

    let (hash) = keccak(task_input, task_input_bytes_len);

    return (ComputationalTask(
        aggregate_fn_id=aggregate_fn_id,
        hash=hash
    ));
}

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
   
    %{
        print(f"data_lake_hash_low: {hex(ids.data_lake_hash_low)}")
        print(f"data_lake_hash_high: {hex(ids.data_lake_hash_high)}")
    %}

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