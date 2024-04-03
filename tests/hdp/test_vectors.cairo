from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.hdp.types import BlockSampledDataLake, BlockSampledComputationalTask

namespace BlockSampledDataLakeMocker {
    func get_header_property() -> (
        datalake_input: felt*,
        datalake_input_bytes_len: felt,
        datalake: BlockSampledDataLake,
        property_type: felt,
    ) {
        alloc_locals;

        let (datalake_input: felt*) = alloc();
        local datalake: BlockSampledDataLake;
        local datalake_bytes_len: felt;

        %{
            ids.datalake.block_range_start = 5382810
            ids.datalake.block_range_end = 5382815
            ids.datalake.increment = 1
            ids.datalake.property_type = 1
            ids.datalake.properties = segments.gen_arg([1, 8])
            ids.datalake.hash.low = 107436943091682614843991191375763387426
            ids.datalake.hash.high = 43197761823970343188211903881620784812

            datalake_input = [0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x9a22520000000000, 0x0, 0x0, 0x0, 0x9f22520000000000, 0x0, 0x0, 0x0, 0x100000000000000, 0x0, 0x0, 0x0, 0xa000000000000000, 0x0, 0x0, 0x0, 0x200000000000000, 0x801, 0x0, 0x0, 0x0]
            ids.datalake_bytes_len = 224
            segments.write_arg(ids.datalake_input, datalake_input)
        %}

        return (datalake_input, datalake_bytes_len, datalake, 1);
    }

    func get_account_property() -> (
        datalake_input: felt*,
        datalake_input_bytes_len: felt,
        datalake: BlockSampledDataLake,
        property_type: felt,
    ) {
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

        return (datalake_input, datalake_bytes_len, datalake, 2);
    }

    func get_storage_property() -> (
        datalake_input: felt*,
        datalake_input_bytes_len: felt,
        datalake: BlockSampledDataLake,
        property_type: felt,
    ) {
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

        return (datalake_input, datalake_bytes_len, datalake, 3);
    }
}

namespace BlockSampledTaskMocker {
    func get_account_task() -> (
        tasks: BlockSampledComputationalTask*,
        tasks_inputs: felt**,
        tasks_bytes_len: felt*,
        datalakes_inputs: felt**,
        datalakes_bytes_len: felt*,
        n_tasks: felt,
    ) {
        alloc_locals;

        %{
            # mocks python params that are available during full flow
            block_sampled_tasks = [{'property_type': 2 }]
        %}

        let (
            account_input, account_input_bytes_len, account_expected_datalake, _
        ) = BlockSampledDataLakeMocker.get_account_property();

        let (datalakes_inputs: felt**) = alloc();
        let (datalakes_bytes_len: felt*) = alloc();
        assert [datalakes_inputs] = account_input;
        assert [datalakes_bytes_len] = account_input_bytes_len;

        let task = BlockSampledComputationalTask(
            aggregate_fn_id=0,
            hash=Uint256(
                low=158898310564618704562379562851344787004,
                high=106587905216569571485640678560526641216,
            ),
            datalake=account_expected_datalake,
        );

        let (tasks: BlockSampledComputationalTask*) = alloc();
        assert [tasks] = task;

        let (tasks_inputs: felt**) = alloc();
        let (tasks_bytes_len: felt*) = alloc();
        %{
            task_input = [[0x8d78d265576f54b2,0x80bbbb9a950be384,0x1b60d9a0cd22820f,0x2a8f25c8f4cc5ee1,0x677661,0x0,0x0,0x0,0x0,0x0,0x0,0x6000000000000000,0x0,0x0,0x0,0x0]]
            tasks_bytes_len = [128]

            segments.write_arg(ids.tasks_inputs, task_input)
            segments.write_arg(ids.tasks_bytes_len, tasks_bytes_len)
        %}

        return (tasks, tasks_inputs, tasks_bytes_len, datalakes_inputs, datalakes_bytes_len, 1);
    }

    func get_avg_params() -> (
        input: felt*, hash_low: felt, hash_high: felt, aggregate_fn_id: felt
    ) {
        let (params) = alloc();
        %{
            avg_param = [0x7b57a805b1991c7e,0xa25f1b72f077813f,0x8c59e10a5510fa64,0xca0ed388358a01bf,0x677661,0x0,0x0,0x0,0x0,0x0,0x0,0x6000000000000000,0x0,0x0,0x0,0x0]
            segments.write_arg(ids.params, avg_param)
        %}

        let datalake_hash_low = 215828760250207880142328954482205465726;
        let datalake_hash_high = 268581037684598511895223889006659959396;
        let aggregate_fn_id = 0;

        return (params, datalake_hash_low, datalake_hash_high, aggregate_fn_id);
    }
    func get_sum_params() -> (
        input: felt*, hash_low: felt, hash_high: felt, aggregate_fn_id: felt
    ) {
        let (params) = alloc();
        %{
            avg_param = [0x7b57a805b1991c7e,0xa25f1b72f077813f,0x8c59e10a5510fa64,0xca0ed388358a01bf,0x6d7573,0x0,0x0,0x0,0x0,0x0,0x0,0x6000000000000000,0x0,0x0,0x0,0x0]
            segments.write_arg(ids.params, avg_param)
        %}

        let datalake_hash_low = 215828760250207880142328954482205465726;
        let datalake_hash_high = 268581037684598511895223889006659959396;
        let aggregate_fn_id = 1;

        return (params, datalake_hash_low, datalake_hash_high, aggregate_fn_id);
    }

    func get_min_params() -> (
        input: felt*, hash_low: felt, hash_high: felt, aggregate_fn_id: felt
    ) {
        let (params) = alloc();
        %{
            avg_param = [0xed3d140441724ef1, 0x90fec1bdd5a2342a, 0x43c796f33033209a, 0xd9c318e200d6db8f, 0x6e696d, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x6000000000000000, 0x0, 0x0, 0x0, 0x0]
            segments.write_arg(ids.params, avg_param)
        %}

        let datalake_hash_low = 192731604340388351313785861398408089329;
        let datalake_hash_high = 289455477656395998637945769668287602842;
        let aggregate_fn_id = 2;

        return (params, datalake_hash_low, datalake_hash_high, aggregate_fn_id);
    }

    func get_max_params() -> (
        input: felt*, hash_low: felt, hash_high: felt, aggregate_fn_id: felt
    ) {
        let (params) = alloc();
        %{
            avg_param = [0xed3d140441724ef1, 0x90fec1bdd5a2342a, 0x43c796f33033209a, 0xd9c318e200d6db8f, 0x78616d, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x6000000000000000, 0x0, 0x0, 0x0, 0x0]
            segments.write_arg(ids.params, avg_param)
        %}

        let datalake_hash_low = 192731604340388351313785861398408089329;
        let datalake_hash_high = 289455477656395998637945769668287602842;
        let aggregate_fn_id = 3;

        return (params, datalake_hash_low, datalake_hash_high, aggregate_fn_id);
    }
}
