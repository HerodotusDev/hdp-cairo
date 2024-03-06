from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.hdp.types import BlockSampledDataLake, BlockSampledComputationalTask

func get_block_sampled_header_test_vector() -> (datalake_input: felt*, datalake_input_bytes_len: felt, datalake: BlockSampledDataLake, property_type: felt) {
    alloc_locals;

    let (datalake_input: felt*) = alloc();
    local datalake: BlockSampledDataLake;
    local datalake_bytes_len: felt;

    %{
        ids.datalake.block_range_start = 5382810
        ids.datalake.block_range_end = 5382815
        ids.datalake.increment = 1
        ids.datalake.property_type = 1
        ids.datalake.properties = segments.gen_arg([8])
        ids.datalake.hash.low = 107436943091682614843991191375763387426
        ids.datalake.hash.high = 43197761823970343188211903881620784812

        datalake_input = [0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x9a22520000000000, 0x0, 0x0, 0x0, 0x9f22520000000000, 0x0, 0x0, 0x0, 0x100000000000000, 0x0, 0x0, 0x0, 0xa000000000000000, 0x0, 0x0, 0x0, 0x200000000000000, 0x801, 0x0, 0x0, 0x0]
        ids.datalake_bytes_len = 224
        segments.write_arg(ids.datalake_input, datalake_input)
    %}

    return (
        datalake_input,
        datalake_bytes_len,
        datalake,
        1
    );
}

func get_block_sampled_account_test_vector() -> (datalake_input: felt*, datalake_input_bytes_len: felt, datalake: BlockSampledDataLake, property_type: felt) {
    alloc_locals;

    let (datalake_input) = alloc();
    local datalake: BlockSampledDataLake;
    local datalake_bytes_len: felt;

    %{
        ids.datalake.block_range_start = 4952100
        ids.datalake.block_range_end = 4952120
        ids.datalake.increment = 1
        ids.datalake.property_type = 2
        ids.datalake.properties = segments.gen_arg([0x2, 0xaad30603936f2c7f, 0x12f5986a6c3a6b73, 0xd43640f7, 0x1])
        ids.datalake.hash.low = 171115948030875793627051908460499129522
        ids.datalake.hash.high = 56570840644286196296062165637174297103

        datalake_input = [0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x24904b0000000000,0x0,0x0,0x0,0x38904b0000000000,0x0,0x0,0x0,0x100000000000000,0x0,0x0,0x0,0xa000000000000000,0x0,0x0,0x0,0x1600000000000000,0xd30603936f2c7f02,0xf5986a6c3a6b73aa,0x1d43640f712,0x0]        
        ids.datalake_bytes_len = 224
        segments.write_arg(ids.datalake_input, datalake_input)
    %}

    return (
        datalake_input,
        datalake_bytes_len,
        datalake,
        2
    );
}

func get_block_sampled_storage_test_vector() -> (datalake_input: felt*, datalake_input_bytes_len: felt, datalake: BlockSampledDataLake, property_type: felt) {
    alloc_locals;

    let (datalake_input) = alloc();
    local datalake: BlockSampledDataLake;
    local datalake_bytes_len: felt;

    %{
        ids.datalake.block_range_start = 5382810
        ids.datalake.block_range_end = 5382815
        ids.datalake.increment = 1
        ids.datalake.property_type = 3
        ids.datalake.properties = segments.gen_arg([0x3, 0x3b7ce9ddbc1ce75, 0x8568f69565aa0e20, 0x20b962c9, 0x0, 0x0, 0x0, 0x200000000000000])
        ids.datalake.hash.low = 215828760250207880142328954482205465726
        ids.datalake.hash.high = 268581037684598511895223889006659959396

        datalake_input = [0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x9a22520000000000,0x0,0x0,0x0,0x9f22520000000000,0x0,0x0,0x0,0x100000000000000,0x0,0x0,0x0,0xa000000000000000,0x0,0x0,0x0,0x3500000000000000,0xb7ce9ddbc1ce7503,0x68f69565aa0e2003,0x20b962c985,0x0,0x0,0x0,0x200000000,0x0]
        ids.datalake_bytes_len = 256
        segments.write_arg(ids.datalake_input, datalake_input)
    %}

    return (
        datalake_input,
        datalake_bytes_len,
        datalake,
        3
    );
}

// func get_block_sampled_tasks_test_vector() -> (
//     tasks: BlockSampledComputationalTask*, 
//     tasks_inputs: felt**, 
//     tasks_bytes_len: felt*, 
//     datalakes_inputs: felt**, 
//     datalakes_bytes_len: felt*,
//     n_tasks: felt
// ) {
//     alloc_locals;

//     %{
//         # mocks python params that are available during full flow
//         block_smapled_tasks = [
//             {"property_type": 1 },
//             {"property_type": 2 },
//             {"property_type": 3 }
//         ]
//     %}

//     let (header_input, header_input_bytes_len, header_expected_datalake, _) = get_block_sampled_header_test_vector();
//     let (account_input, account_input_bytes_len, account_expected_datalake, _) = get_block_sampled_account_test_vector();
//     let (storage_input, storage_input_bytes_len, storage_expected_datalake, _) = get_block_sampled_storage_test_vector();

//     let (tasks: BlockSampledComputationalTask*) = alloc();
//     let (tasks_inputs: felt**) = alloc();
//     let (tasks_bytes_len: felt*) = alloc();
//     let (datalakes_inputs: felt**) = alloc();
//     let (datalakes_bytes_len: felt*) = alloc();

//     %{

    
//     %}
// }