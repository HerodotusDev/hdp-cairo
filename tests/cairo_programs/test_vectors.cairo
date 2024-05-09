from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.builtin_keccak.keccak import keccak
from src.types import BlockSampledDataLake, ComputationalTask
from src.tasks.computational import AGGREGATE_FN
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin

from src.datalakes.datalake import DatalakeType
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
            ids.datalake.properties = segments.gen_arg([8])

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
            ids.datalake.properties = segments.gen_arg([0x1, 0xaad30603936f2c7f, 0x12f5986a6c3a6b73, 0xd43640f7])

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
            ids.datalake.properties = segments.gen_arg([0x3b7ce9ddbc1ce75, 0x8568f69565aa0e20, 0x20b962c9, 0x0, 0x0, 0x0, 0x200000000000000])

            datalake_input = [0x0,0x0,0x0,0x0,0x0,0x0,0x0,0x9a22520000000000,0x0,0x0,0x0,0x9f22520000000000,0x0,0x0,0x0,0x100000000000000,0x0,0x0,0x0,0xa000000000000000,0x0,0x0,0x0,0x3500000000000000,0xb7ce9ddbc1ce7503,0x68f69565aa0e2003,0x20b962c985,0x0,0x0,0x0,0x200000000,0x0]
            ids.datalake_bytes_len = 256
            segments.write_arg(ids.datalake_input, datalake_input)
        %}

        return (datalake_input, datalake_bytes_len, datalake, 3);
    }
}

namespace BlockSampledTaskMocker {
    func get_init_data() -> (
        task: ComputationalTask,
        tasks_inputs: felt**,
        tasks_bytes_len: felt*,
        datalake: BlockSampledDataLake,
        datalakes_inputs: felt**,
        datalakes_bytes_len: felt*,
        tasks_len: felt,
    ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, prop_id
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        let (tasks_bytes_len) = alloc();

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            # mocks python params that are available during full flow
            block_sampled_tasks = [{'property_type': 1 }]
            task_bytes = bytes.fromhex("22B4DA4CC94620C9DFCC5AE7429AD350AC86587E6D9925A6209587EF17967F20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            segments.write_arg(ids.tasks_bytes_len, [len(task_bytes)])
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let task = ComputationalTask(
            hash=Uint256(
                low=0x407E98D423A7BB2DBF09B0E42601FC9B, high=0xEF8B01F35B404615F0339EEFAE7719A2
            ),
            datalake_ptr=cast(&datalake, felt*),
            datalake_type=0,
            aggregate_fn_id=AGGREGATE_FN.AVG,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (tasks_inputs: felt**) = alloc();
        let (datalakes_inputs: felt**) = alloc();
        let (datalakes_bytes_len: felt*) = alloc();
        assert tasks_inputs[0] = task_input;
        assert datalakes_inputs[0] = datalake_input;
        assert datalakes_bytes_len[0] = datalake_bytes_len;

        return (
            task, tasks_inputs, tasks_bytes_len, datalake, datalakes_inputs, datalakes_bytes_len, 1
        );
    }

    func get_avg_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little

            task_bytes = bytes.fromhex("22B4DA4CC94620C9DFCC5AE7429AD350AC86587E6D9925A6209587EF17967F20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            hash=Uint256(
                low=0x407E98D423A7BB2DBF09B0E42601FC9B, high=0xEF8B01F35B404615F0339EEFAE7719A2
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.AVG,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_sum_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("22B4DA4CC94620C9DFCC5AE7429AD350AC86587E6D9925A6209587EF17967F20000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            hash=Uint256(
                low=0x3CB6684D1B4B7FDEA3FBACAEA422C944, high=0x02F8516E3F7BE7FCCFDE22FB4A98DF37
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.SUM,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_min_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("22B4DA4CC94620C9DFCC5AE7429AD350AC86587E6D9925A6209587EF17967F20000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            hash=Uint256(
                low=0x9F439795EE0CA868B463479E5A905BF0, high=0x72CEFA1188B199ECEEAB39767CD32605
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.MIN,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_max_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("22B4DA4CC94620C9DFCC5AE7429AD350AC86587E6D9925A6209587EF17967F20000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            hash=Uint256(
                low=0x1CD2E160D860B4D1BD1E327B6AA209BD, high=0xCABA4809710EB228D6A31DE1B852DFB7
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.MAX,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_count_if_task{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
    }() -> (
        task: ComputationalTask,
        tasks_inputs: felt*,
        tasks_bytes_len: felt,
        datalake: BlockSampledDataLake,
        datalake_hash: Uint256,
    ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("22B4DA4CC94620C9DFCC5AE7429AD350AC86587E6D9925A6209587EF17967F200000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000186a0")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}
        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            hash=Uint256(
                low=0xAE5641FEA9032C936D7E54D7CF36E2C3, high=0xA53CFAB970F9780B3C39CFAC1DD3D425
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.COUNT,
            ctx_operator=1,
            ctx_value=Uint256(low=0x186a0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }
}
